import SwiftUI

struct BetaUpdatesView: View {
    @ObservedObject var betaAccess: BetaAccessManager
    @ObservedObject var updateChecker: UpdateChecker

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PhasePageHeader(
                    title: "Beta & Updates",
                    subtitle: "Review beta access and check for Garmin Screen Studio updates.",
                    symbol: "clock.badge.checkmark"
                ) {
                    StudioStatusBadge(
                        title: betaAccess.hasValidAccess ? "Beta Active" : "Beta Expired",
                        systemImage: betaAccess.hasValidAccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        style: betaAccess.hasValidAccess ? .healthy : .warning
                    )
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    betaAccessCard
                    updatesCard
                }
            }
            .padding(24)
        }
        .background(Color.panelBackground)
    }

    private var betaAccessCard: some View {
        StudioCard(title: "Beta Access", symbol: "checkmark.seal", prominence: .soft) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(betaAccess.hasValidAccess ? Color.green : Color.orange)
                        .frame(width: 13, height: 13)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(betaAccess.hasValidAccess ? "Active" : "Expired or Required")
                            .font(.title3.weight(.semibold))
                        Text(betaAccess.hasValidAccess ? "\(betaAccess.daysRemaining) days remaining" : "Activation is required before using the app.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(spacing: 8) {
                    StudioMetricRow(title: "Status", detail: betaAccess.hasValidAccess ? "Active" : "Inactive", systemImage: betaAccess.hasValidAccess ? "checkmark.circle.fill" : "xmark.circle.fill", tint: betaAccess.hasValidAccess ? .green : .red)
                    StudioMetricRow(title: "Days Remaining", detail: "\(betaAccess.daysRemaining)", systemImage: "calendar", tint: .blue)
                    StudioMetricRow(title: "Activation Date", detail: betaAccess.activationDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Not available", systemImage: "clock", tint: Color(nsColor: .secondaryLabelColor))
                    StudioMetricRow(title: "Expiry Date", detail: betaAccess.expiryDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Not available", systemImage: "calendar.badge.clock", tint: Color(nsColor: .secondaryLabelColor))
                }
            }
        }
    }

    private var updatesCard: some View {
        StudioCard(title: "Software Update", symbol: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 56, height: 56)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.blue.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Garmin Screen Studio")
                            .font(.title3.weight(.semibold))
                        Text("Version \(appVersionText) · Build \(buildNumberText)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(spacing: 8) {
                    StudioMetricRow(title: "Version", detail: appVersionText, systemImage: "app", tint: .blue)
                    StudioMetricRow(title: "Build", detail: buildNumberText, systemImage: "number", tint: .blue)
                    StudioMetricRow(title: "Update Check", detail: updateChecker.canCheckForUpdates ? "Ready" : "Busy", systemImage: "arrow.triangle.2.circlepath", tint: updateChecker.canCheckForUpdates ? .green : .orange)
                }

                Button {
                    updateChecker.checkForUpdates()
                } label: {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!updateChecker.canCheckForUpdates)

                Text("Garmin Screen Studio checks for updates using the app's existing update system.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
