import Foundation

class FFmpegRunner {

    /// Homebrew's standard install locations, checked in order. No longer
    /// pinned to one specific Cellar version — that broke the moment ffmpeg
    /// updated, and never existed at all on any machine but the dev one.
    private let candidatePaths = [
        "/opt/homebrew/bin/ffmpeg",   // Apple Silicon Homebrew
        "/usr/local/bin/ffmpeg"       // Intel Homebrew
    ]

    private func resolvedFFmpegPath() -> String? {

        for path in candidatePaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        return resolveViaShellPath(for: "ffmpeg")
    }

    private func resolvedFFprobePath(ffmpegPath: String) -> String {
        URL(fileURLWithPath: ffmpegPath)
            .deletingLastPathComponent()
            .appendingPathComponent("ffprobe")
            .path
    }

    private func resolveViaShellPath(for tool: String) -> String? {

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", tool]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (path?.isEmpty == false) ? path : nil
        } catch {
            return nil
        }
    }

    /// Runs ffmpeg. `completion` reports success and, on failure, a
    /// human-readable reason instead of just a bare Bool.
    func convert(folder: URL, outputFile: URL, framerate: Double, completion: @escaping (Bool, String?) -> Void) {

        guard let ffmpegPath = resolvedFFmpegPath() else {
            let message = "ffmpeg isn't installed. Install it with Homebrew: brew install ffmpeg"
            print("❌ \(message)")
            DispatchQueue.main.async { completion(false, message) }
            return
        }

        let process = Process()

        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.currentDirectoryURL = folder

        let framerateArg = String(format: "%.4f", framerate)

        process.arguments = [
            "-y",
            "-framerate", framerateArg,
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

            DispatchQueue.main.async {
                if success {
                    completion(true, nil)
                } else {
                    completion(false, "ffmpeg exited with an error — check the console log for details")
                }
            }
        }

        do {
            try process.run()
        } catch {
            print(error)
            DispatchQueue.main.async {
                completion(false, "Couldn't launch ffmpeg: \(error.localizedDescription)")
            }
        }
    }

    /// Counts frames actually encoded into an MP4. Returns nil quietly if
    /// ffmpeg/ffprobe can't be found — conversion itself will already have
    /// failed with a clear message in that case, so this just skips the
    /// extra check rather than erroring a second time.
    func countEncodedFrames(videoFile: URL, completion: @escaping (Int?) -> Void) {

        guard let ffmpegPath = resolvedFFmpegPath() else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let ffprobePath = resolvedFFprobePath(ffmpegPath: ffmpegPath)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobePath)

        process.arguments = [
            "-v", "error",
            "-count_frames",
            "-select_streams", "v:0",
            "-show_entries", "stream=nb_read_frames",
            "-of", "default=nokey=1:noprint_wrappers=1",
            videoFile.path
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        process.terminationHandler = { process in

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let count = text.flatMap { Int($0) }

            DispatchQueue.main.async {
                completion(count)
            }
        }

        do {
            try process.run()
        } catch {
            print(error)
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
}
