import Foundation

class RecordingCache {

    private let fileManager = FileManager.default
    private let converter = VideoConverter()

    var cacheFolder: URL {

        URL(fileURLWithPath:
            NSHomeDirectory() + "/Movies/Garmin Screen Studio/Latest Recording"
        )

    }

    func clear(log: ((String) -> Void)? = nil) {

        log?("🧹 Cleared previous recording")
        print("🟢 RecordingCache.clear()")

        do {

            let files = try fileManager.contentsOfDirectory(
                at: cacheFolder,
                includingPropertiesForKeys: nil
            )

            for file in files {

                if file.pathExtension.lowercased() == "bmp" {

                    try? fileManager.removeItem(at: file)

                }

            }

        } catch {

            log?("📁 Recording folder doesn't exist yet")

        }

    }

    /// Converts the cached BMP frames to an MP4 at the given framerate.
    /// `completion` reports the output URL on success, or nil plus a
    /// human-readable error message on failure (e.g. ffmpeg not installed).
    func convertLatestRecording(framerate: Double, completion: @escaping (URL?, String?) -> Void) {

        guard let images = try? fileManager.contentsOfDirectory(
            at: cacheFolder,
            includingPropertiesForKeys: nil
        )
        .filter({ $0.pathExtension.lowercased() == "bmp" })
        .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        else {

            completion(nil, "No recording files found to convert.")
            return

        }

        converter.convert(images: images, framerate: framerate, completion: completion)

    }

    /// Counts the frames actually encoded into a finished MP4.
    func encodedFrameCount(of video: URL, completion: @escaping (Int?) -> Void) {
        converter.frameCount(of: video, completion: completion)
    }

}
