import SwiftUI
import AppKit
import Sentry

@main
struct Garmin_Screen_Studio_v1_1App: App {

    init() {
        configureCrashReporting()
    }

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

    // MARK: - Crash reporting (Sentry)

    private func configureCrashReporting() {

        SentrySDK.start { options in

            options.dsn = "https://b01d5a710ea0d8f9c6fd7d80ed28c549@o4511789665157120.ingest.de.sentry.io/4511789669220432"

            // Crash reporting only — no performance tracing, no session/analytics tracking.
            options.tracesSampleRate = 0.0
            options.enableAutoSessionTracking = false
            options.enableAutoPerformanceTracing = false
            options.debug = false
        }

        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString

        SentrySDK.configureScope { scope in
            scope.setTag(value: shortVersion, key: "app_version")
            scope.setTag(value: buildNumber, key: "build_number")
            scope.setTag(value: macOSVersion, key: "macos_version")
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

        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        let versionText = "Version \(shortVersion) (Build \(buildNumber))"

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Garmin Screen Studio",
            .applicationVersion: versionText,
            .version: "",
            .credits: credits,
            .applicationIcon: NSApp.applicationIconImage ?? NSImage()
        ])

    }

}
