import Foundation

class DownloadRunner {

    func download() {

        let process = Process()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")

        process.arguments = [
            NSHomeDirectory() + "/Desktop/download-bmps.sh"
        ]

        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe

        do {

            try process.run()

            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: data, encoding: .utf8) ?? ""

            print("========== DOWNLOAD ==========")
            print(output)
            print("==============================")

        } catch {

            print(error)

        }

    }

}
