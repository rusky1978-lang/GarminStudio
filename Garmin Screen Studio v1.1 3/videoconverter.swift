import Foundation

class VideoConverter {

    private let runner = FFmpegRunner()

    @discardableResult
    func convert(images: [URL]) -> URL? {

        guard let firstImage = images.first else {
            print("❌ No images found.")
            return nil
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

        runner.convert(
            folder: cacheFolder,
            outputFile: outputFile
        )

        return outputFile
    }
}
