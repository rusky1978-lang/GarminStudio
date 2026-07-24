import SwiftUI
import AppKit

@main
struct Garmin_Screen_Studio_v1_1App: App {

    var body: some Scene {

        WindowGroup {

            ContentView()

        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Garmin Screen Studio") {
                    showAboutPanel()
                }
            }
        }

        Settings {

            VStack(spacing: 20) {

                Text("Garmin Screen Studio")
                    .font(.title)
                    .bold()

                Text("Settings coming soon…")
                    .foregroundStyle(.secondary)

            }
            .padding(40)
            .frame(width: 350)

        }

    }

    private func showAboutPanel() {

        let credits = NSMutableAttributedString(
            string: "Import and convert Garmin Edge screen recordings.\n\nBuilt by Cycling with Russ\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        let link = NSAttributedString(
            string: "youtube.com/@CyclingwithRuss",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .link: URL(string: "https://www.youtube.com/@CyclingwithRuss")!,
                .foregroundColor: NSColor.linkColor
            ]
        )

        credits.append(link)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        credits.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: credits.length)
        )

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Garmin Screen Studio",
            .applicationVersion: "1.1",
            .credits: credits,
            .applicationIcon: NSApp.applicationIconImage ?? NSImage()
        ])

    }

}
