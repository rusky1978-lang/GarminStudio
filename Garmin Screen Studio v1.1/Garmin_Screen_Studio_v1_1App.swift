import SwiftUI
import AppKit
import Combine
import Sparkle

final class SparkleProductionConfiguration: NSObject, SPUUpdaterDelegate {
    // TODO: Set this to the production appcast URL, or add SUFeedURL in the target Info settings.
    private static let appcastURLString: String? = nil

    private static let publicEDKey: String? = "gh4ttnTbfFrDequS0xD/WbHyurUFvzVVKsMpyqgzNVM="

    var isReadyForUpdater: Bool {
        hasFeedURL && hasPublicEDKey
    }

    private var hasFeedURL: Bool {
        Self.appcastURLString != nil || Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
    }

    private var hasPublicEDKey: Bool {
        Self.publicEDKey != nil || Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        Self.appcastURLString
    }
}

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates: Bool

    init(updater: SPUUpdater, hasUpdateFeed: Bool) {
        canCheckForUpdates = !hasUpdateFeed || updater.canCheckForUpdates

        guard hasUpdateFeed else {
            return
        }

        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    private let hasUpdateFeed: Bool

    init(updater: SPUUpdater, hasUpdateFeed: Bool) {
        self.updater = updater
        self.hasUpdateFeed = hasUpdateFeed
        viewModel = CheckForUpdatesViewModel(updater: updater, hasUpdateFeed: hasUpdateFeed)
    }

    var body: some View {
        Button("Check for Updates…") {
            if hasUpdateFeed {
                updater.checkForUpdates()
            } else {
                NSAlert.noUpdatesAvailable.runModal()
            }
        }
        .disabled(!viewModel.canCheckForUpdates)
    }
}

private extension NSAlert {
    static var noUpdatesAvailable: NSAlert {
        let alert = NSAlert()
        alert.messageText = "No Updates Available"
        alert.informativeText = "Garmin Screen Studio is up to date."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        return alert
    }
}

@main
struct Garmin_Screen_Studio_v1_1App: App {
    private let sparkleConfiguration: SparkleProductionConfiguration
    private let updaterController: SPUStandardUpdaterController
    private let hasUpdateFeed: Bool

    init() {
        let sparkleConfiguration = SparkleProductionConfiguration()
        self.sparkleConfiguration = sparkleConfiguration
        hasUpdateFeed = sparkleConfiguration.isReadyForUpdater
        updaterController = SPUStandardUpdaterController(
            startingUpdater: hasUpdateFeed,
            updaterDelegate: sparkleConfiguration,
            userDriverDelegate: nil
        )
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

            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(
                    updater: updaterController.updater,
                    hasUpdateFeed: hasUpdateFeed
                )
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
