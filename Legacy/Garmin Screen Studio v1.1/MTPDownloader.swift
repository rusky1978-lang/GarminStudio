import Foundation

class MTPDownloader {

    func downloadTestImage() {

        let process = Process()

        let desktop = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
            .appendingPathComponent("Image-0000.BMP")

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")

        process.arguments = [
            "-lc",
            "/opt/homebrew/bin/mtp-getfile 4041 \"\(desktop.path)\""
        ]

        process.environment = ProcessInfo.processInfo.environment

        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe

        do {
            print(process.executableURL?.path ?? "")
            print(process.arguments ?? [])
            print(process.environment ?? [:])
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            print("========== MTP ==========")
            print(output)
            print("=========================")

            if FileManager.default.fileExists(atPath: desktop.path) {

                print("✅ Download worked!")

            } else {

                print("❌ File not found")

            }

        } catch {

            print("❌ Failed to run process")
            print(error)

        }

    }

}
