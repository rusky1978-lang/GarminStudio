import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var mtp: MTPManager
    @ObservedObject var betaAccess: BetaAccessManager
    let exportDiagnostics: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PhasePageHeader(
                    title: "Diagnostics",
                    subtitle: "Check Garmin Screen Studio and export a report for troubleshooting.",
                    symbol: "stethoscope"
                ) {
                    healthBadge
                }

                healthSummary

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    systemHealthCard
                    reportCard
                }
            }
            .padding(24)
        }
        .background(Color.panelBackground)
    }

    private var healthBadge: some View {
        switch healthState {
        case .healthy:
            StudioStatusBadge(title: "Ready", systemImage: "checkmark.circle.fill", style: .healthy)
        case .warning:
            StudioStatusBadge(title: "Attention Needed", systemImage: "exclamationmark.triangle.fill", style: .warning)
        case .failure:
            StudioStatusBadge(title: "Problem", systemImage: "xmark.circle.fill", style: .failure)
        case .neutral:
            StudioStatusBadge(title: "Not Tested", systemImage: "circle", style: .neutral)
        }
    }

    private var healthSummary: some View {
        StudioCard(title: "Health Summary", symbol: healthState.symbol, prominence: .soft) {
            HStack(spacing: 16) {
                Image(systemName: healthState.symbol)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(healthState.tint)
                    .frame(width: 64, height: 64)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(healthState.tint.opacity(0.12)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(healthTitle)
                        .font(.title3.weight(.semibold))
                    Text(healthMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    exportDiagnostics()
                } label: {
                    Label("Export Diagnostics Report", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var systemHealthCard: some View {
        StudioCard(title: "System Health", symbol: "checkmark.seal") {
            VStack(spacing: 8) {
                SystemHealthRow(
                    title: "Garmin Device",
                    detail: mtp.deviceConnected ? mtp.deviceName : "No device connected",
                    state: mtp.deviceConnected ? .healthy : .warning
                )
                SystemHealthRow(
                    title: "Device Communication",
                    detail: mtp.deviceConnected ? "Ready" : "Waiting for Garmin",
                    state: mtp.deviceConnected ? .healthy : .warning
                )
                SystemHealthRow(
                    title: "Video Conversion",
                    detail: ffmpegExists ? "Ready" : "Unavailable",
                    state: ffmpegExists ? .healthy : .failure
                )
                SystemHealthRow(
                    title: "Storage",
                    detail: mtp.storageFreeGB.map { String(format: "%.1f GB free", $0) } ?? "Not reported by current device state",
                    state: mtp.storageFreeGB == nil ? .neutral : .healthy
                )
                SystemHealthRow(
                    title: "Imported Recording",
                    detail: mtp.importComplete ? "\(mtp.importedFileCount) BMP files imported" : "No import completed this session",
                    state: mtp.importComplete ? .healthy : .neutral
                )
                SystemHealthRow(
                    title: "Beta Access",
                    detail: "\(betaAccess.daysRemaining) days remaining",
                    state: betaAccess.hasValidAccess ? .healthy : .failure
                )
            }
        }
    }

    private var reportCard: some View {
        StudioCard(title: "Support Report", symbol: "doc.text") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Send this report when reporting an issue.")
                    .font(.headline)

                Text("The report includes app version, macOS version, Garmin connection state, recording/import/conversion state, and current log entries for troubleshooting.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                VStack(spacing: 8) {
                    StudioMetricRow(title: "App Version", detail: appVersionText, systemImage: "app", tint: .blue)
                    StudioMetricRow(title: "Build", detail: buildNumberText, systemImage: "number", tint: .blue)
                    StudioMetricRow(title: "macOS", detail: ProcessInfo.processInfo.operatingSystemVersionString, systemImage: "desktopcomputer", tint: Color(nsColor: .secondaryLabelColor))
                }

                Button {
                    exportDiagnostics()
                } label: {
                    Label("Export Diagnostics Report", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var ffmpegExists: Bool {
        FileManager.default.fileExists(atPath: FFmpegRunner.ffmpegPath)
    }

    private var healthState: SystemHealthRow.State {
        if !ffmpegExists || !betaAccess.hasValidAccess {
            return .failure
        }
        if !mtp.deviceConnected {
            return .warning
        }
        return .healthy
    }

    private var healthTitle: String {
        switch healthState {
        case .healthy: "Ready"
        case .warning: "Attention Needed"
        case .failure: "Problem Detected"
        case .neutral: "Not Tested"
        }
    }

    private var healthMessage: String {
        switch healthState {
        case .healthy:
            return "Garmin Screen Studio is ready to import and convert recordings."
        case .warning:
            return "The app is running, but no Garmin device is currently connected."
        case .failure:
            return "A required app capability is unavailable. Export diagnostics before changing the working app configuration."
        case .neutral:
            return "Run the normal workflow to populate diagnostics state."
        }
    }

    private var appVersionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var buildNumberText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
}
