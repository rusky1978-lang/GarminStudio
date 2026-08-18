import SwiftUI

struct SettingsDestinationView: View {
    @ObservedObject var updateChecker: UpdateChecker
    let openSettings: () -> Void
    let checkForUpdates: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PhasePageHeader(
                    title: "Settings",
                    subtitle: "App information and existing preference entry points.",
                    symbol: "gearshape"
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    generalCard
                    updatesCard
                    aboutCard
                }
            }
            .padding(24)
        }
        .background(Color.panelBackground)
    }

    private var generalCard: some View {
        StudioCard(title: "General", symbol: "switch.2") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Garmin Screen Studio follows your macOS appearance setting automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                StudioMetricRow(title: "Appearance", detail: "System", systemImage: "circle.lefthalf.filled", tint: .blue)
                StudioMetricRow(title: "Output Folder", detail: "~/Movies/Garmin Screen Studio", systemImage: "folder", tint: Color(nsColor: .secondaryLabelColor))

                Button {
                    openSettings()
                } label: {
                    Label("Open Native Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var updatesCard: some View {
        StudioCard(title: "Updates", symbol: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: 14) {
                StudioMetricRow(title: "Update Check", detail: updateChecker.canCheckForUpdates ? "Ready" : "Busy", systemImage: "arrow.triangle.2.circlepath", tint: updateChecker.canCheckForUpdates ? .green : .orange)

                Button {
                    checkForUpdates()
                } label: {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!updateChecker.canCheckForUpdates)

                Text("Release notes and installation are handled by the app's existing update flow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutCard: some View {
        StudioCard(title: "About", symbol: "info.circle", prominence: .soft) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    AppIdentityMark(size: 50)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Garmin Screen Studio")
                            .font(.title3.weight(.semibold))
                        Text("Version \(appVersionText) · Build \(buildNumberText)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                StudioMetricRow(title: "Creator", detail: "Cycling with Russ", systemImage: "person.crop.circle", tint: .blue)
                StudioMetricRow(title: "Purpose", detail: "Import Garmin screen recordings and turn them into videos", systemImage: "film.stack", tint: Color(nsColor: .secondaryLabelColor))
            }
        }
    }

    private var appVersionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var buildNumberText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
}
