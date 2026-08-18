import Foundation

/// Stage 2 of the diagnostics system.
///
/// Builds a single, human-readable diagnostics report as plain text,
/// suitable for a user to copy and email to the developer.
///
/// This stage only *generates* the report string. It does not write
/// anything to disk, copy to the clipboard, or expose any UI — those
/// come in a later stage.
struct DiagnosticsReport {

    /// Builds the full diagnostics report.
    ///
    /// - Parameter mtpManager: The app's `MTPManager`, used to read live
    ///   device, recording, import, and conversion state. `MTPManager` is
    ///   owned by `ContentView` (not a singleton), so it's passed in here
    ///   rather than looked up globally. Pass `nil` to still get a valid
    ///   report with those sections marked as unavailable.
    static func generateReport(mtpManager: MTPManager? = nil) -> String {

        let sections: [String] = [
            appInfoSection(),
            systemInfoSection(),
            toolingSection(),
            deviceSection(mtpManager),
            recordingSection(mtpManager),
            importSection(mtpManager),
            conversionSection(mtpManager),
            logSection(),
            errorSection()
        ]

        return sections.joined(separator: "\n\n")
    }

    // MARK: - App info

    private static func appInfoSection() -> String {

        let info = Bundle.main.infoDictionary
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = info?["CFBundleVersion"] as? String ?? "Unknown"

        return """
        GARMIN SCREEN STUDIO — DIAGNOSTICS REPORT
        Generated: \(currentDateTimeText())

        App Version: \(appVersion)
        Build Number: \(buildNumber)
        """
    }

    // MARK: - System info

    private static func systemInfoSection() -> String {

        return """
        SYSTEM
        macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Architecture: \(machineArchitecture())
        """
    }

    private static func machineArchitecture() -> String {
        #if arch(arm64)
        return "arm64 (Apple Silicon)"
        #elseif arch(x86_64)
        return "x86_64 (Intel)"
        #else
        return "Unknown"
        #endif
    }

    // MARK: - Tooling

    private static func toolingSection() -> String {

        let ffmpegPath = FFmpegRunner.ffmpegPath
        let ffmpegLine = FileManager.default.fileExists(atPath: ffmpegPath)
            ? "FFmpeg Path: \(ffmpegPath)"
            : "FFmpeg Path: Not found (expected at \(ffmpegPath))"

        return """
        TOOLING
        \(ffmpegLine)
        libmtp Version: \(libmtpVersionText())
        """
    }

    /// The current libmtp bindings used by this project (see
    /// `CLibMTP/shim.h`) don't expose a confirmed version string API, so
    /// this reports "Not available" for now rather than guessing at a
    /// symbol that might not compile against every libmtp build.
    private static func libmtpVersionText() -> String {
        "Not available"
    }

    // MARK: - Garmin device

    private static func deviceSection(_ mtp: MTPManager?) -> String {

        guard let mtp else {
            return "GARMIN DEVICE\nNot available"
        }

        guard mtp.deviceConnected else {
            return "GARMIN DEVICE\nNo device connected"
        }

        let storageText = mtp.storageFreeGB.map { String(format: "%.2f GB free", $0) } ?? "Unknown"

        return """
        GARMIN DEVICE
        Connected: Yes
        Device Name: \(mtp.deviceName)
        Storage: \(storageText)
        """
    }

    // MARK: - Recording information

    private static func recordingSection(_ mtp: MTPManager?) -> String {

        guard let mtp else {
            return "RECORDING INFORMATION\nNot available"
        }

        guard !mtp.recordings.isEmpty || !mtp.latestRecordingFolderName.isEmpty else {
            return "RECORDING INFORMATION\nNo recordings found"
        }

        var lines = ["RECORDING INFORMATION", "Recordings Found: \(mtp.recordings.count)"]

        if !mtp.latestRecordingFolderName.isEmpty {
            lines.append("Latest Recording: \(mtp.latestRecordingFolderName)")
        }

        if let date = mtp.latestRecordingDate {
            lines.append("Latest Recording Date: \(dateTimeFormatter.string(from: date))")
        }

        if !mtp.latestRecordingDimensions.isEmpty {
            lines.append("Latest Recording Dimensions: \(mtp.latestRecordingDimensions)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Import statistics

    private static func importSection(_ mtp: MTPManager?) -> String {

        guard let mtp else {
            return "IMPORT STATISTICS\nNot available"
        }

        guard mtp.importComplete else {
            return "IMPORT STATISTICS\nNo import completed yet"
        }

        return """
        IMPORT STATISTICS
        Files Imported: \(mtp.importedFileCount)
        Data Imported: \(mtp.dataImportedText)
        Import Duration: \(mtp.importDurationText)
        """
    }

    // MARK: - Conversion statistics

    private static func conversionSection(_ mtp: MTPManager?) -> String {

        guard let mtp else {
            return "CONVERSION STATISTICS\nNot available"
        }

        guard mtp.conversionComplete else {
            return "CONVERSION STATISTICS\nNo conversion completed yet"
        }

        let outputText = mtp.outputVideo?.lastPathComponent ?? "Unknown"

        return """
        CONVERSION STATISTICS
        Output Video: \(outputText)
        """
    }

    // MARK: - Logger entries

    private static func logSection() -> String {

        let entries = Logger.shared.entries

        guard !entries.isEmpty else {
            return "LOG ENTRIES\nNo log entries recorded"
        }

        let lines = entries.map { $0.formattedText }
        return "LOG ENTRIES\n" + lines.joined(separator: "\n")
    }

    // MARK: - Stored error messages

    private static func errorSection() -> String {

        let errors = Logger.shared.entries.filter { $0.level == .error }

        guard !errors.isEmpty else {
            return "STORED ERROR MESSAGES\nNo errors recorded"
        }

        let lines = errors.map { $0.formattedText }
        return "STORED ERROR MESSAGES\n" + lines.joined(separator: "\n")
    }

    // MARK: - Formatting helpers

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static func currentDateTimeText() -> String {
        dateTimeFormatter.string(from: Date())
    }
}
