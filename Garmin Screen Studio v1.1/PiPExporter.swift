import Foundation
import AVFoundation
import AppKit

enum PiPExportError: LocalizedError {
    case missingVideoTrack
    case noOverlap
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack: return "Couldn't find a video track in one of the clips."
        case .noOverlap: return "These clips don't overlap in time once synced — check the sync offset."
        case .exportFailed(let reason): return "Export failed: \(reason)"
        }
    }
}

/// Builds and exports a basic Picture-in-Picture video: camera footage
/// full-frame as the background, the synced Garmin recording small in
/// the bottom-right corner. Built entirely on AVFoundation's composition
/// stack (AVMutableComposition + AVMutableVideoComposition) — no Metal,
/// no Core Image, no ffmpeg — per the Creator Mode design document's
/// Section 5 recommendation.
enum PiPExporter {

    static func export(
        garminURL: URL,
        cameraURL: URL,
        syncOffset: TimeInterval,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {

        Task {
            do {
                let outputURL = try await buildAndExport(
                    garminURL: garminURL,
                    cameraURL: cameraURL,
                    syncOffset: syncOffset,
                    progress: progress
                )
                await MainActor.run { completion(.success(outputURL)) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    private static func buildAndExport(
        garminURL: URL,
        cameraURL: URL,
        syncOffset: TimeInterval,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {

        let garminAsset = AVURLAsset(url: garminURL)
        let cameraAsset = AVURLAsset(url: cameraURL)

        guard
            let garminTrack = try await garminAsset.loadTracks(withMediaType: .video).first,
            let cameraTrack = try await cameraAsset.loadTracks(withMediaType: .video).first
        else {
            throw PiPExportError.missingVideoTrack
        }

        let garminDuration = try await garminAsset.load(.duration)
        let cameraDuration = try await cameraAsset.load(.duration)

        // syncOffset = seconds the camera should start relative to the
        // Garmin recording's own t=0 (positive = camera starts later).
        // Both insertion points below are shifted so neither is ever
        // negative on the composition's own timeline.
        let garminInsertion = max(0, -syncOffset)
        let cameraInsertion = max(0, syncOffset)

        let garminStart = garminInsertion
        let garminEnd = garminInsertion + CMTimeGetSeconds(garminDuration)
        let cameraStart = cameraInsertion
        let cameraEnd = cameraInsertion + CMTimeGetSeconds(cameraDuration)

        let overlapStart = max(garminStart, cameraStart)
        let overlapEnd = min(garminEnd, cameraEnd)

        guard overlapEnd > overlapStart else {
            throw PiPExportError.noOverlap
        }

        let composition = AVMutableComposition()

        guard
            let compGarminTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let compCameraTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw PiPExportError.missingVideoTrack
        }

        try compGarminTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: garminDuration),
            of: garminTrack,
            at: CMTime(seconds: garminInsertion, preferredTimescale: 600)
        )

        try compCameraTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: cameraDuration),
            of: cameraTrack,
            at: CMTime(seconds: cameraInsertion, preferredTimescale: 600)
        )

        // Carry over the camera's own audio, if it has any — the Garmin
        // recording never has audio (it's a screen capture), so the
        // camera is the only possible audio source here.
        if let cameraAudioTrack = try? await cameraAsset.loadTracks(withMediaType: .audio).first,
           let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compAudioTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: cameraDuration),
                of: cameraAudioTrack,
                at: CMTime(seconds: cameraInsertion, preferredTimescale: 600)
            )
        }

        // MARK: - Layout: camera full-frame background, Garmin small PiP bottom-right

        let cameraNaturalTransform = try await cameraTrack.load(.preferredTransform)
        let cameraNaturalSize = try await cameraTrack.load(.naturalSize)
        let orientedCameraSize = cameraNaturalSize.applying(cameraNaturalTransform)
        let renderSize = CGSize(width: abs(orientedCameraSize.width), height: abs(orientedCameraSize.height))

        let garminNaturalTransform = try await garminTrack.load(.preferredTransform)
        let garminNaturalSize = try await garminTrack.load(.naturalSize)
        let orientedGarminSize = garminNaturalSize.applying(garminNaturalTransform)
        let garminSize = CGSize(width: abs(orientedGarminSize.width), height: abs(orientedGarminSize.height))

        let pipWidth = renderSize.width * 0.28
        let pipHeight = garminSize.width > 0 ? pipWidth * (garminSize.height / garminSize.width) : pipWidth
        let margin = renderSize.width * 0.03
        let pipOrigin = CGPoint(x: renderSize.width - pipWidth - margin, y: margin)

        let scale = garminSize.width > 0 ? pipWidth / garminSize.width : 1
        let garminTransform = garminNaturalTransform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: pipOrigin.x, y: pipOrigin.y))

        _ = pipHeight // reserved for future use (e.g. rounded-corner masking)

        let cameraLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compCameraTrack)
        cameraLayerInstruction.setTransform(cameraNaturalTransform, at: .zero)

        let garminLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compGarminTrack)
        garminLayerInstruction.setTransform(garminTransform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        // Garmin (PiP) listed first so it renders ON TOP of the camera background.
        instruction.layerInstructions = [garminLayerInstruction, cameraLayerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]

        // MARK: - Export

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw PiPExportError.exportFailed("Couldn't create export session")
        }

        let outputFolder = URL(fileURLWithPath: NSHomeDirectory() + "/Movies/Garmin Screen Studio/Creator Mode")
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let outputURL = outputFolder.appendingPathComponent("PiP \(formatter.string(from: Date())).mp4")

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: overlapStart, preferredTimescale: 600),
            end: CMTime(seconds: overlapEnd, preferredTimescale: 600)
        )

        let progressTask = Task {
            while !Task.isCancelled {
                await MainActor.run { progress(Double(exportSession.progress)) }
                if exportSession.progress >= 1.0 { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                if let error = exportSession.error {
                    continuation.resume(throwing: error)
                } else if exportSession.status == .completed {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PiPExportError.exportFailed("Export ended with status: \(exportSession.status.rawValue)"))
                }
            }
        }

        progressTask.cancel()
        await MainActor.run { progress(1.0) }

        return outputURL
    }
}
