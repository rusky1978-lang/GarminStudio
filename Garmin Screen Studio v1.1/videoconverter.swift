import Foundation

class VideoConverter {

    private let runner = FFmpegRunner()

    /// Converts the given BMP frames to an MP4 at the given framerate.
    /// `completion` reports the output URL on success, or nil plus a
    /// human-readable error message on failure.
    func convert(images: [URL], framerate: Double, completion: @escaping (URL?, String?) -> Void) {

        guard let firstImage = images.first else {
            let message = "No images found."
            print("❌ \(message)")
            completion(nil, message)
            return
        }

        let cacheFolder = firstImage.deletingLastPathComponent()

        let videosFolder = cacheFolder
            .deletingLastPathComponent()
            .appendingPathComponent("Videos")
        try? FileManager.default.createDirectory(
            at: videosFolder,
            withIntermediateDirectories: true
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"

        let filename = formatter.string(from: Date()) + ".mp4"

        let outputFile = videosFolder.appendingPathComponent(filename)

        print("🚀 Starting conversion...")
        print("📂 Cache Folder: \(cacheFolder.path)")
        print("🎥 Videos Folder: \(videosFolder.path)")
        print("🎞️ Frames: \(images.count)")
        print("⏱️ Framerate: \(framerate) fps")

        runner.convert(
            folder: cacheFolder,
            outputFile: outputFile,
            framerate: framerate
        ) { success, errorMessage in
            completion(success ? outputFile : nil, errorMessage)
        }
    }

    /// Counts the frames actually encoded into a finished MP4.
    func frameCount(of video: URL, completion: @escaping (Int?) -> Void) {
        runner.countEncodedFrames(videoFile: video, completion: completion)
    }
}
