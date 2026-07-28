import Foundation
import Combine
import ImageIO
import CoreGraphics

struct ActivityItem: Identifiable {
    let id = UUID()
    let message: String
    let time: Date

    var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: time)
    }
}

class MTPManager: ObservableObject {

    // Console-style technical log (kept for debugging)
    @Published var activityLog: [String] = []

    // Sidebar "Recent Activity" feed
    @Published var recentActivity: [ActivityItem] = []

    // Device info
    @Published var deviceConnected = false
    @Published var deviceName = "No Device"
    @Published var storageFreeGB: Double? = nil

    // Recording browser
    @Published var recordings: [GarminRecording] = []
    @Published var isScanningRecordings = false
    @Published var scanStatus = ""

    // Import state
    @Published var isImporting = false
    @Published var importComplete = false
    @Published var importProgress: Double = 0
    @Published var importStatus = "Browse your Garmin to choose a recording to import"
    @Published var importedFileCount = 0
    @Published var importDurationText = "--:--"
    @Published var dataImportedText = "-- MB"
    @Published var importedImageURLs: [URL] = []
    @Published var latestRecordingFolderName = ""
    @Published var latestRecordingDate: Date?
    @Published var latestRecordingDimensions = ""

    // Measured capture rate (from real device timestamps, not a guess)
    @Published var measuredCaptureFPS: Double? = nil

    // Conversion state
    @Published var isConverting = false
    @Published var conversionComplete = false
    @Published var outputVideo: URL?
    @Published var conversionErrorMessage: String? = nil

    // Frame integrity (post-conversion verification)
    @Published var encodedFrameCount: Int? = nil
    @Published var frameIntegrityText: String = ""

    private var importStartTime: Date?

    // The interval (in seconds) actually used to encode the video.
    // Defaults to the app's original fixed rate (2 fps = 0.5s) until we
    // manage to measure a real one from the device.
    private var currentFrameInterval: Double = 0.5

    private let cache = RecordingCache()
    private let garmin = GarminDevice()

    // MARK: - Thread-safe UI helpers

    func log(_ message: String) {
        DispatchQueue.main.async {
            print(message)
            self.activityLog.append(message)
            if self.activityLog.count > 8 {
                self.activityLog.removeFirst()
            }
        }
    }

    private func logActivity(_ message: String) {
        DispatchQueue.main.async {
            self.recentActivity.insert(ActivityItem(message: message, time: Date()), at: 0)
            if self.recentActivity.count > 6 {
                self.recentActivity.removeLast()
            }
        }
    }

    private func setStatus(_ text: String) {
        DispatchQueue.main.async { self.importStatus = text }
    }

    private func setScanStatus(_ text: String) {
        DispatchQueue.main.async { self.scanStatus = text }
    }

    private func setProgress(_ value: Double) {
        DispatchQueue.main.async { self.importProgress = value }
    }

    // MARK: - Scanning (Recording Browser)

    func scanRecordings() {

        isScanningRecordings = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            self.setScanStatus("🔍 Looking for Garmin...")

            LIBMTP_Init()

            guard let device = LIBMTP_Get_First_Device() else {
                DispatchQueue.main.async {
                    self.isScanningRecordings = false
                    self.deviceConnected = false
                    self.recordings = []
                }
                return
            }

            let modelName = self.garmin.deviceModelName(device)
            let freeGB = self.garmin.freeStorageGB(device)

            DispatchQueue.main.async {
                self.deviceConnected = true
                self.deviceName = modelName
                self.storageFreeGB = freeGB
            }

            self.setScanStatus("📂 Scanning recordings...")

            guard let folders = LIBMTP_Get_Folder_List(device) else {
                LIBMTP_Release_Device(device)
                DispatchQueue.main.async { self.isScanningRecordings = false }
                return
            }

            let folderInfos = self.garmin.allRecordingFolders(folders)

            let files = LIBMTP_Get_Filelisting_With_Callback(device, nil, nil)

            var counts: [UInt32: Int] = [:]
            var current: UnsafeMutablePointer<LIBMTP_file_t>? = files

            while let file = current {
                let filename = String(cString: file.pointee.filename)
                if filename.uppercased().hasSuffix(".BMP") {
                    counts[file.pointee.parent_id, default: 0] += 1
                }
                current = file.pointee.next
            }

            if let files {
                LIBMTP_destroy_file_t(files)
            }

            LIBMTP_Release_Device(device)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

            let results: [GarminRecording] = folderInfos.map { info in
                GarminRecording(
                    id: info.framesFolderID,
                    dateFolderID: info.dateFolderID,
                    name: info.name,
                    date: formatter.date(from: info.name),
                    imageCount: counts[info.framesFolderID] ?? 0
                )
            }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

            DispatchQueue.main.async {
                self.recordings = results
                self.isScanningRecordings = false
                self.scanStatus = ""
            }
        }
    }

    // MARK: - Import

    func importRecording(_ recording: GarminRecording) {
        performImport(folderID: recording.id, displayName: recording.name)
    }

    private func performImport(folderID: UInt32, displayName: String) {

        importComplete = false
        conversionComplete = false
        conversionErrorMessage = nil
        isImporting = true
        importProgress = 0
        importedImageURLs = []
        outputVideo = nil
        importStartTime = Date()
        measuredCaptureFPS = nil
        encodedFrameCount = nil
        frameIntegrityText = ""

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            self.cache.clear(log: { message in self.log(message) })

            self.setStatus("🔍 Connecting to Garmin...")
            self.log("🚀 Initialising libmtp...")

            LIBMTP_Init()

            guard let device = LIBMTP_Get_First_Device() else {
                print("❌ No device found")
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.deviceConnected = false
                }
                return
            }

            self.setStatus("🟢 Garmin Connected")
            self.log("🟢 Garmin connected")
            self.log("📂 Importing \(displayName)")

            let files = LIBMTP_Get_Filelisting_With_Callback(device, nil, nil)

            // Grab real per-frame timestamps BEFORE printFiles runs, since
            // printFiles destroys this file listing once it's done.
            let timestamps = self.garmin.frameTimestamps(files, parentFolderID: folderID)

            self.garmin.printFiles(
                files,
                device: device,
                parentFolderID: folderID,
                progressUpdate: { progress in self.setProgress(progress) },
                statusUpdate: { status in self.setStatus(status) }
            )

            LIBMTP_Release_Device(device)

            self.log("✅ Import complete")
            self.setStatus("✅ Import Complete!")

            let images = (try? FileManager.default.contentsOfDirectory(
                at: self.cache.cacheFolder,
                includingPropertiesForKeys: [.fileSizeKey]
            ))?
            .filter { $0.pathExtension.lowercased() == "bmp" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []

            var totalBytes: Int64 = 0
            for image in images {
                if let size = try? image.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalBytes += Int64(size)
                }
            }

            var dimensionsText = ""
            if let first = images.first,
               let source = CGImageSourceCreateWithURL(first as CFURL, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
               let width = props[kCGImagePropertyPixelWidth] as? Int,
               let height = props[kCGImagePropertyPixelHeight] as? Int {
                dimensionsText = "\(width) x \(height)"
            }

            let duration = Date().timeIntervalSince(self.importStartTime ?? Date())
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60

            // Measure the real interval between captured frames.
            let measuredInterval = self.measuredFrameInterval(from: timestamps)
            self.currentFrameInterval = measuredInterval ?? 0.5

            if let measuredInterval {
                self.log(String(format: "📏 Measured capture rate: %.2f fps (from device timestamps)", 1.0 / measuredInterval))
            } else {
                self.log("⚠️ Couldn't measure capture rate from device — using default 2 fps")
            }

            DispatchQueue.main.async {
                self.isImporting = false
                self.importComplete = true
                self.importProgress = 1.0
                self.importedFileCount = images.count
                self.importedImageURLs = images
                self.dataImportedText = self.formatBytes(totalBytes)
                self.importDurationText = String(format: "%02d:%02d", minutes, seconds)
                self.latestRecordingDimensions = dimensionsText
                self.latestRecordingDate = Date()
                self.latestRecordingFolderName = displayName
                self.measuredCaptureFPS = measuredInterval.map { 1.0 / $0 }
            }

            self.logActivity("Imported \(images.count) files from \(displayName)")
        }
    }

    /// Calculates the real average interval between captured frames, using
    /// the total time span across ALL frames divided by the number of gaps
    /// — rather than looking at individual frame-to-frame deltas.
    ///
    /// This matters because the Garmin's MTP timestamps only have
    /// whole-second precision: individual gaps would mostly round to 0 or 1
    /// second and be useless on their own, but averaging the total span
    /// across hundreds of frames cancels that quantization out and gives an
    /// accurate sub-second capture rate.
    private func measuredFrameInterval(from timestamps: [GarminDevice.FrameTimestamp]) -> Double? {

        guard timestamps.count >= 2 else { return nil }

        let sorted = timestamps.sorted { $0.filename < $1.filename }

        guard let first = sorted.first?.date, let last = sorted.last?.date else { return nil }

        let totalSpan = last.timeIntervalSince(first)
        let gapCount = Double(sorted.count - 1)

        guard totalSpan > 0, gapCount > 0 else { return nil }

        return totalSpan / gapCount
    }

    // MARK: - Delete

    func deleteRecordings(_ toDelete: [GarminRecording]) {

        guard !toDelete.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            LIBMTP_Init()

            guard let device = LIBMTP_Get_First_Device() else { return }

            let files = LIBMTP_Get_Filelisting_With_Callback(device, nil, nil)

            for recording in toDelete {

                self.log("🗑️ Deleting \(recording.name)")

                var current: UnsafeMutablePointer<LIBMTP_file_t>? = files

                while let file = current {
                    if file.pointee.parent_id == recording.id {
                        LIBMTP_Delete_Object(device, file.pointee.item_id)
                    }
                    current = file.pointee.next
                }

                LIBMTP_Delete_Object(device, recording.id)
                LIBMTP_Delete_Object(device, recording.dateFolderID)
            }

            if let files {
                LIBMTP_destroy_file_t(files)
            }

            LIBMTP_Release_Device(device)

            self.log("✅ Deleted \(toDelete.count) recording(s)")
            self.logActivity("Deleted \(toDelete.count) recording(s)")

            DispatchQueue.main.async {
                let deletedIDs = Set(toDelete.map { $0.id })
                self.recordings.removeAll { deletedIDs.contains($0.id) }
            }
        }
    }

    // MARK: - Conversion

    func convertToVideo() {

        guard !importedImageURLs.isEmpty else { return }

        isConverting = true
        conversionComplete = false
        conversionErrorMessage = nil
        encodedFrameCount = nil
        frameIntegrityText = ""

        setStatus("🎬 Converting to video...")

        let framerate = 1.0 / currentFrameInterval

        cache.convertLatestRecording(framerate: framerate) { [weak self] video, errorMessage in
            guard let self else { return }
            self.isConverting = false

            guard let video else {
                let message = errorMessage ?? "Video conversion failed"
                self.setStatus("❌ \(message)")
                self.log("❌ \(message)")
                self.conversionErrorMessage = message
                self.logActivity("Conversion failed")
                return
            }

            self.outputVideo = video
            self.conversionComplete = true
            self.setStatus("✅ Video converted")
            self.log("🎥 Saved: \(video.lastPathComponent)")
            self.logActivity("Converted to MP4")
            self.logActivity("Saved to Movies folder")

            // Verify no frames were dropped between capture → download → encode.
            self.cache.encodedFrameCount(of: video) { encoded in
                self.encodedFrameCount = encoded

                let expected = self.importedImageURLs.count

                if let encoded {
                    if encoded == expected {
                        self.frameIntegrityText = "✅ \(encoded)/\(expected) frames encoded — nothing dropped"
                    } else {
                        self.frameIntegrityText = "⚠️ \(encoded)/\(expected) frames encoded — some frames may have been dropped"
                    }
                    self.log(self.frameIntegrityText)
                } else {
                    self.frameIntegrityText = "Frame count could not be verified"
                }
            }
        }
    }

    // MARK: - Estimates

    var estimatedConversionSizeText: String {
        let estimateMB = Double(importedImageURLs.count) * 1.05
        if estimateMB >= 1024 {
            return String(format: "~%.2f GB", estimateMB / 1024)
        }
        return String(format: "~%.0f MB", estimateMB)
    }

    var estimatedConversionTimeText: String {
        let seconds = Double(importedImageURLs.count) * 0.3
        let minutes = max(1, Int(seconds / 60))
        return "\(minutes) - \(minutes + 2) minutes"
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576.0
        return String(format: "%.0f MB", mb)
    }

    func isGarminConnected() -> Bool {
        LIBMTP_Init()
        guard let device = LIBMTP_Get_First_Device() else { return false }
        LIBMTP_Release_Device(device)
        return true
    }

}
