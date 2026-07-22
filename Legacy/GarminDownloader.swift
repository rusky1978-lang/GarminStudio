import Foundation

class GarminDownloader {

    let downloadFolder: URL

    init() {

        let movies = FileManager.default.urls(
            for: .moviesDirectory,
            in: .userDomainMask
        ).first!

        downloadFolder = movies
            .appendingPathComponent("Garmin Screen Studio")
            .appendingPathComponent("Latest Recording")

        createFolder()
    }

    private func createFolder() {

        try? FileManager.default.removeItem(at: downloadFolder)

        try? FileManager.default.createDirectory(
            at: downloadFolder,
            withIntermediateDirectories: true
        )
    }

    func downloadTestImage() {

        let process = Process()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")

        process.arguments = [
            "-c",
            """
            export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:$PATH
            export LANG=en_GB.UTF-8
            mtp-getfile 4041 "\(downloadFolder.appendingPathComponent("Image-0000.BMP").path)"
            """
        ]

        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe

        do {

            try process.run()

            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: data, encoding: .utf8) ?? ""

            print(output)

            if FileManager.default.fileExists(
                atPath: downloadFolder.appendingPathComponent("Image-0000.BMP").path
            ) {

                print("✅ Download worked!")

            } else {

                print("❌ Download failed")

            }

        } catch {

            print(error)

        }

    }

}
