import Foundation

class MTPRunner {

    private let mtpFolders = "/opt/homebrew/bin/mtp-folders"

    func latestRecording() -> GarminRecording? {

        let process = Process()
        process.executableURL = URL(fileURLWithPath: mtpFolders)

        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("❌ Failed to run mtp-folders")
            print(error)
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        print("========== MTP OUTPUT ==========")
        print(output)
        print("===============================")

        return findLatestRecording(in: output)
    }

    func listFiles() {

        if let latest = latestRecording() {

            print("🟢 Garmin Edge 1050 Connected")
            print("")
            print("Latest Recording")
            print(latest.folderName)
            print("")
            print("Folder ID: \(latest.folderID)")

        } else {

            print("❌ No recordings found.")

        }

    }

    private func findLatestRecording(in text: String) -> GarminRecording? {

        let lines = text.components(separatedBy: .newlines)

        var recordings: [GarminRecording] = []

        for line in lines {

            print("LINE -> [\(line)]")

            if !line.contains("2026-") {
                continue
            }

            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })

            if parts.count >= 2 {

                let id = Int(parts[0]) ?? 0
                let name = String(parts[1])

                recordings.append(
                    GarminRecording(
                        folderID: id,
                        folderName: name
                    )
                )

            }

        }

        recordings.sort {
            $0.folderName < $1.folderName
        }

        return recordings.last

    }

}
