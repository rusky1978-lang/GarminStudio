import Foundation

class FFmpegRunner {

    private let ffmpegPath = "/opt/homebrew/Cellar/ffmpeg/8.1.2_1/bin/ffmpeg"

    func convert(folder: URL, outputFile: URL) {

        let process = Process()

        process.executableURL = URL(fileURLWithPath: ffmpegPath)

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

            DispatchQueue.main.async {

                print("========== FFMPEG ==========")
                print(output)
                print("============================")

                if process.terminationStatus == 0 {
                    print("✅ Video created")
                } else {
                    print("❌ FFmpeg failed")
                }
            }
        }

        do {
            try process.run()
        } catch {
            print(error)
        }
    }
}
