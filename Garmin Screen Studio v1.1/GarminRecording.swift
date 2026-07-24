import Foundation

/// One recording folder discovered on the Garmin device.
/// `id` is the folder that actually contains the BMP frames; `dateFolderID`
/// is its parent (the date-named folder) — we keep both so delete can clean
/// up both folder levels.
struct GarminRecording: Identifiable, Hashable {

    let id: UInt32
    let dateFolderID: UInt32
    let name: String
    let date: Date?
    let imageCount: Int

    // Garmin's screen recorder doesn't expose a real capture interval
    // anywhere we can read it, so this is a labelled estimate, not an
    // exact reading from the device.
    static let estimatedSecondsPerFrame: Double = 1.0

    var estimatedDuration: TimeInterval {
        Double(imageCount) * GarminRecording.estimatedSecondsPerFrame
    }

    var durationText: String {
        let total = Int(estimatedDuration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    var dateText: String {
        guard let date else { return name }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
