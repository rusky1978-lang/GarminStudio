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

    func convertLatestRecording() -> URL? {

        guard let images = try? fileManager.contentsOfDirectory(
            at: cacheFolder,
            includingPropertiesForKeys: nil
        )
        .filter({ $0.pathExtension.lowercased() == "bmp" })
        .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        else {

            return nil

        }

        return converter.convert(images: images)

    }

}
