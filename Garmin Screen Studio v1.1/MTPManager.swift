import Foundation
import Combine

@MainActor
class MTPManager: ObservableObject {

    @Published var status = "🔌 Connect your Garmin and press Import Latest Recording"
    @Published var activityLog: [String] = []
    @Published var progress: Double = 0
    @Published var isWorking = false
    @Published var finished = false
    @Published var outputVideo: URL?

    private var parentFolderID: UInt32 = 0

    private let cache = RecordingCache()
    private let garmin = GarminDevice()

    func log(_ message: String) {
        print(message)
        activityLog.append(message)
        if activityLog.count > 8 {
            activityLog.removeFirst()
        }
    }

    func test() {

        finished = false
        isWorking = true
        progress = 0

        cache.clear()

        status = "🔍 Looking for Garmin..."
        log("🚀 Initialising libmtp...")

        LIBMTP_Init()

        guard let device = LIBMTP_Get_First_Device() else {
            print("❌ No device found")
            isWorking = false
            return
        }

        status = "🟢 Garmin Connected"
        log("🟢 Garmin connected")

        guard let folders = LIBMTP_Get_Folder_List(device) else {
            print("❌ Folder tree is nil")
            LIBMTP_Release_Device(device)
            isWorking = false
            return
        }

        log("📂 Reading latest recording")

        if let latestRecording = garmin.latestRecordingFolder(folders) {

            print("")
            print("Latest recording folder ID: \(latestRecording)")

            parentFolderID = latestRecording

            print("Child folder ID: \(latestRecording)")
            print("")
            print("📂 Loading complete file listing...")

            let files = LIBMTP_Get_Filelisting_With_Callback(
                device,
                nil,
                nil
            )

            print("✅ File list loaded")
            print("")

            garmin.printFiles(
                files,
                device: device,
                parentFolderID: parentFolderID,
                progressUpdate: { progress in
                    self.progress = progress
                },
                statusUpdate: { status in
                    self.status = status
                }
            )
        }

        LIBMTP_Release_Device(device)

        print("")
        log("✅ Import complete")
        status = "✅ Finished"

        isWorking = false
        finished = true
        progress = 1.0

        if let video = cache.convertLatestRecording() {
            outputVideo = video
            status = "✅ Video converted"
            log("🎥 Saved: \(video.lastPathComponent)")
        }
    }

    func isGarminConnected() -> Bool {

        LIBMTP_Init()

        guard let device = LIBMTP_Get_First_Device() else {
            return false
        }

        LIBMTP_Release_Device(device)
        return true
    }

}
