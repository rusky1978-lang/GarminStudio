import Foundation

class FFmpegRunner {

    static var ffmpegPath: String {
        Bundle.main.path(forResource: "ffmpeg", ofType: nil) ?? "ffmpeg"
    }

    /// Runs ffmpeg and reports back via `completion` once the process has
    /// actually terminated (success/failure), instead of returning immediately.
    /// `completion` is always called on the main thread.
    func convert(folder: URL, outputFile: URL, completion: @escaping (Bool) -> Void) {

        let process = Process()

        process.executableURL = URL(fileURLWithPath: Self.ffmpegPath)

        // Tell FFmpeg to look for the BMP files in the Garmin folder
        process.currentDirectoryURL = folder

        process.arguments = [
            "-y",
            "-framerate", "2",
            "-start_number", "0",
            "-i", "Image-%04d.BMP",
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            outputFile.path
        ]

        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe

        process.terminationHandler = { process in

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            print("========== FFMPEG ==========")
            print(output)
            print("============================")

            let success = process.terminationStatus == 0

            if success {
                print("Video created")
            } else {
                print("FFmpeg failed")
            }

            DispatchQueue.main.async {
                completion(success)
            }
        }

        do {
            try process.run()
        } catch {
            print(error)
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
}
