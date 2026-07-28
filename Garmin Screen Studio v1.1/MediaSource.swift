import Foundation
import AVFoundation
import AppKit

/// A single time-based media clip that Creator Mode can work with.
/// Deliberately knows nothing about Garmin, libmtp, or how it was
/// produced — Creator Mode only ever sees "a video file with some
/// metadata," never touches MTPManager or GarminDevice directly.
protocol MediaSource: Identifiable {
    var id: UUID { get }
    var displayName: String { get }
    var url: URL { get }
}

/// A camera clip (GoPro, DJI, Insta360, or any standard video file)
/// imported by the user for a Creator Mode project.
struct CameraSource: MediaSource {

    let id = UUID()
    let url: URL
    let displayName: String

    var duration: TimeInterval?
    var thumbnail: NSImage?

    /// Seconds this clip should start relative to the Garmin recording's
    /// start. Positive = camera starts AFTER the Garmin recording.
    /// Deliberately a single value — whether set by marking matching
    /// moments in SyncView or by hand-nudging, it's always this one
    /// number, never a separate "automatic" field that could diverge.
    var syncOffset: TimeInterval = 0

    /// Tracked separately from syncOffset == 0, since a genuinely synced
    /// pair could legitimately have a zero offset — using the offset
    /// value itself as a "has this been synced" proxy was a real bug.
    var isSynced: Bool = false

    // Picture-in-Picture export state for this specific clip.
    var isExporting: Bool = false
    var exportProgress: Double = 0
    var exportedVideoURL: URL?
    var exportErrorMessage: String?

    init(url: URL) {
        self.url = url
        self.displayName = url.lastPathComponent
    }
}

/// Wraps an already-converted Garmin recording (the MP4 produced by the
/// existing import → convert pipeline, or one picked manually from disk)
/// as a Creator Mode media source. This is the ONLY place Creator Mode
/// touches anything from the main app — everything else works purely in
/// terms of MediaSource.
struct GarminRecordingSource: MediaSource {

    let id = UUID()
    let url: URL
    let displayName: String
    var duration: TimeInterval?
    var thumbnail: NSImage?

    init(url: URL, thumbnail: NSImage?) {
        self.url = url
        self.displayName = url.lastPathComponent
        self.thumbnail = thumbnail
    }
}

/// Shared helper for loading a clip's duration and a preview thumbnail
/// via AVFoundation, used by both source types above.
enum MediaSourceLoader {

    static func loadDuration(for url: URL, completion: @escaping (TimeInterval?) -> Void) {
        let asset = AVURLAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(duration)
                await MainActor.run {
                    completion(seconds.isFinite ? seconds : nil)
                }
            } catch {
                await MainActor.run { completion(nil) }
            }
        }
    }

    static func loadThumbnail(for url: URL, completion: @escaping (NSImage?) -> Void) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        Task {
            do {
                let result = try await generator.image(at: .zero)
                let image = NSImage(cgImage: result.image, size: .zero)
                await MainActor.run { completion(image) }
            } catch {
                await MainActor.run { completion(nil) }
            }
        }
    }
}
