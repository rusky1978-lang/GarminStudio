import Foundation
import Combine

/// Severity level for a single diagnostics log entry.
enum LogLevel: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
}

/// A single timestamped diagnostics log entry.
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    var timestampText: String {
        LogEntry.timeFormatter.string(from: timestamp)
    }

    /// e.g. "[2026-07-30 14:03:12] [INFO] Garmin device detected"
    var formattedText: String {
        "[\(timestampText)] [\(level.rawValue)] \(message)"
    }
}

/// Reusable diagnostics logging system.
///
/// This is stage one: capture, timestamp, print to console, and keep
/// entries in memory (observable via `@Published`) so a future Log
/// Viewer/export feature can read from a single source of truth.
final class Logger: ObservableObject {

    static let shared = Logger()

    private init() {}

    @Published private(set) var entries: [LogEntry] = []

    private func log(_ message: String, level: LogLevel) {

        let entry = LogEntry(timestamp: Date(), level: level, message: message)

        print(entry.formattedText)

        DispatchQueue.main.async {
            self.entries.append(entry)
        }

    }

    static func info(_ message: String) {
        shared.log(message, level: .info)
    }

    static func success(_ message: String) {
        shared.log(message, level: .success)
    }

    static func warning(_ message: String) {
        shared.log(message, level: .warning)
    }

    static func error(_ message: String) {
        shared.log(message, level: .error)
    }
}
