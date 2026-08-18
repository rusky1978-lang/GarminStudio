import AppKit
import Combine
import Sparkle

final class UpdateChecker: ObservableObject {
    @Published var canCheckForUpdates: Bool

    private let updater: SPUUpdater?
    private let hasUpdateFeed: Bool
    private var cancellable: AnyCancellable?

    init(updater: SPUUpdater? = nil, hasUpdateFeed: Bool = false) {
        self.updater = updater
        self.hasUpdateFeed = hasUpdateFeed
        canCheckForUpdates = updater.map { !hasUpdateFeed || $0.canCheckForUpdates } ?? false

        guard let updater, hasUpdateFeed else {
            return
        }

        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .sink { [weak self] canCheck in
                self?.canCheckForUpdates = canCheck
            }
    }

    func checkForUpdates() {
        guard hasUpdateFeed, let updater else {
            let alert = NSAlert()
            alert.messageText = "No Updates Available"
            alert.informativeText = "Garmin Screen Studio is up to date."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        updater.checkForUpdates()
    }
}
