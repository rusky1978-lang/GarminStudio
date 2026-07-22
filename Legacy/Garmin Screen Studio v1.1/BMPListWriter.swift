import Foundation

class BMPListWriter {

    func write(lines: [String]) {

        let url = URL(fileURLWithPath:
            NSHomeDirectory() + "/Desktop/bmp_ids.txt"
        )

        let text = lines.joined(separator: "\n")

        do {

            try text.write(
                to: url,
                atomically: true,
                encoding: .utf8
            )

            print("✅ bmp_ids.txt created")

        } catch {

            print(error)

        }

    }

}
