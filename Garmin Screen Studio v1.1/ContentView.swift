import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

// MARK: - Palette

extension Color {
    static let panelBackground = Color(nsColor: NSColor(name: nil) { appearance in
        let bestMatch = appearance.bestMatch(from: [.aqua, .darkAqua])
        return bestMatch == .darkAqua
            ? NSColor(red: 0.085, green: 0.09, blue: 0.10, alpha: 1.0)
            : NSColor(red: 0.925, green: 0.955, blue: 0.985, alpha: 1.0)
    })
    static let sidebarBackground = Color(nsColor: .controlBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let elevatedCardBackground = Color(nsColor: NSColor(name: nil) { appearance in
        let bestMatch = appearance.bestMatch(from: [.aqua, .darkAqua])
        return bestMatch == .darkAqua
            ? NSColor(red: 0.125, green: 0.13, blue: 0.145, alpha: 1.0)
            : .windowBackgroundColor
    })
    static let softCardBackground = Color(nsColor: NSColor(name: nil) { appearance in
        let bestMatch = appearance.bestMatch(from: [.aqua, .darkAqua])
        return bestMatch == .darkAqua
            ? NSColor(red: 0.105, green: 0.11, blue: 0.125, alpha: 1.0)
            : NSColor(red: 0.975, green: 0.985, blue: 1.0, alpha: 1.0)
    })
    static let cardBorder = Color(nsColor: .separatorColor).opacity(0.42)
    static let brandStroke = Color(nsColor: .labelColor)
    static let brandIcon = Color(nsColor: .labelColor)
}

struct ContentView: View {

    private enum SidebarDestination: String, CaseIterable, Identifiable {
        case overview
        case devices
        case recordings
        case convert
        case diagnostics
        case betaUpdates
        case settings

        var id: Self { self }

        var title: String {
            switch self {
            case .overview: "Overview"
            case .devices: "Devices"
            case .recordings: "Recordings"
            case .convert: "Convert"
            case .diagnostics: "Diagnostics"
            case .betaUpdates: "Beta & Updates"
            case .settings: "Settings"
            }
        }

        var symbol: String {
            switch self {
            case .overview: "rectangle.grid.2x2"
            case .devices: "externaldrive.connected.to.line.below"
            case .recordings: "list.bullet.rectangle"
            case .convert: "film"
            case .diagnostics: "stethoscope"
            case .betaUpdates: "clock.badge.checkmark"
            case .settings: "gearshape"
            }
        }
    }

    private struct RecordingDateSection: Identifiable {
        let id: String
        let title: String
        let recordings: [GarminRecording]
    }

    @StateObject private var mtp = MTPManager()
    @StateObject private var betaAccess = BetaAccessManager()
    @StateObject private var updateChecker: UpdateChecker
    @State private var showRecordingBrowser = false
    @State private var sidebarSelection: SidebarDestination = .overview
    @State private var selectedRecordingIDs = Set<UInt32>()
    @State private var showDeleteConfirmation = false

    init(updateChecker: UpdateChecker = UpdateChecker()) {
        _updateChecker = StateObject(wrappedValue: updateChecker)
    }

    var body: some View {
        mainContent
    }

    @ViewBuilder
    private var mainContent: some View {
        if betaAccess.hasValidAccess {
            applicationContent
        } else {
            BetaActivationView(betaAccess: betaAccess)
                .frame(minWidth: 980, minHeight: 660)
        }
    }

    private var applicationContent: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 300)
        } detail: {
            destinationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.panelBackground)
        }
        .frame(minWidth: 1100, idealWidth: 1180, maxWidth: .infinity, minHeight: 700, idealHeight: 760, maxHeight: .infinity)
        .sheet(isPresented: $showRecordingBrowser) {
            RecordingBrowserView(mtp: mtp)
        }
        .alert("Delete Selected Recordings?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedRecordings()
            }
        } message: {
            Text("This removes the selected recording folders from the connected Garmin. This cannot be undone.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    AppIdentityMark(size: 40)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Garmin Screen Studio")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text("Version 1.1")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 10)
            }

            List(selection: $sidebarSelection) {
                Section {
                    ForEach(SidebarDestination.allCases) { destination in
                        Label(destination.title, systemImage: destination.symbol)
                            .tag(destination)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(betaAccess.hasValidAccess ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(betaAccess.hasValidAccess ? "Beta Active" : "Beta Required")
                        .font(.caption.weight(.medium))
                }

                Text("\(betaAccess.daysRemaining) days remaining")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.cardBackground.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.cardBorder)
            )
            .padding(14)
        }
        .background(Color.sidebarBackground)
    }

    @ViewBuilder
    private var destinationView: some View {
        switch sidebarSelection {
        case .overview:
            overviewScreen
        case .devices:
            devicesScreen
        case .recordings:
            recordingsScreen
        case .convert:
            ConvertView(
                mtp: mtp,
                browseRecordings: { sidebarSelection = .recordings },
                exportDiagnostics: exportDiagnostics
            )
        case .diagnostics:
            DiagnosticsView(
                mtp: mtp,
                betaAccess: betaAccess,
                exportDiagnostics: exportDiagnostics
            )
        case .betaUpdates:
            BetaUpdatesView(
                betaAccess: betaAccess,
                updateChecker: updateChecker
            )
        case .settings:
            SettingsDestinationView(
                updateChecker: updateChecker,
                openSettings: openSettings,
                checkForUpdates: updateChecker.checkForUpdates
            )
        }
    }

    // MARK: - Overview

    private var overviewScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                overviewHeader

                if mtp.deviceConnected {
                    connectedDeviceHero
                } else {
                    disconnectedDeviceHero
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    storageSummaryCard
                    recordingsSummaryCard
                    importSummaryCard
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Quick Actions")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        QuickActionCard(
                            title: "Browse Recordings",
                            subtitle: "Open the main recording browser",
                            symbol: "list.bullet.rectangle",
                            accent: .blue,
                            isDisabled: mtp.isImporting
                        ) {
                            sidebarSelection = .recordings
                        }

                        QuickActionCard(
                            title: "Convert to MP4",
                            subtitle: mtp.importComplete ? "Create a video from imported frames" : "Import a recording first",
                            symbol: "film",
                            accent: .blue,
                            isDisabled: !mtp.importComplete || mtp.isConverting
                        ) {
                            mtp.convertToVideo()
                        }

                        QuickActionCard(
                            title: "Diagnostics",
                            subtitle: "Export a support report",
                            symbol: "stethoscope",
                            accent: .indigo
                        ) {
                            exportDiagnostics()
                        }

                        QuickActionCard(
                            title: "Settings",
                            subtitle: "Open app preferences",
                            symbol: "gearshape",
                            accent: .gray
                        ) {
                            openSettings()
                        }
                    }
                }

                recentActivityPanel
            }
            .padding(24)
        }
    }

    private var overviewHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Welcome back")
                    .font(.system(size: 32, weight: .bold, design: .default))
                Text(overviewSubtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            overviewStatusBadge
        }
    }

    private var overviewSubtitle: String {
        if mtp.isImporting { return mtp.importStatus }
        if mtp.isConverting { return "Converting imported frames to MP4." }
        if mtp.deviceConnected { return "\(mtp.deviceName) is ready for recordings." }
        return "Connect your Garmin Edge to get started."
    }

    private var overviewStatusBadge: some View {
        if mtp.isImporting || mtp.isConverting || mtp.isScanningRecordings {
            StatusBadge(title: "Working", systemImage: "arrow.triangle.2.circlepath", style: .working)
        } else if mtp.deviceConnected {
            StatusBadge(title: "All Systems Healthy", systemImage: "checkmark.circle.fill", style: .healthy)
        } else {
            StatusBadge(title: "No Device", systemImage: "circle", style: .neutral)
        }
    }

    private var connectedDeviceHero: some View {
        DeviceHeroCard(
            title: mtp.deviceName,
            subtitle: "Ready to import recordings",
            status: "Connected",
            statusStyle: .healthy
        ) {
            DeviceMetric(title: "Storage", value: storageFreeText, symbol: "internaldrive")
            DeviceMetric(title: "Recordings", value: "\(mtp.recordings.count)", symbol: "folder")
            DeviceMetric(title: "Import", value: mtp.importComplete ? "Ready" : "Waiting", symbol: "arrow.down.circle")
        } actions: {
            Button {
                sidebarSelection = .recordings
            } label: {
                Label("Recordings", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.borderedProminent)

            Button {
                mtp.scanRecordings()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(mtp.isScanningRecordings)
        }
    }

    private var disconnectedDeviceHero: some View {
        DashboardCard(title: "No Garmin Connected", symbol: "externaldrive.badge.questionmark") {
            HStack(alignment: .center, spacing: 18) {
                Image(systemName: "cable.connector.horizontal")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 62, height: 62)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.blue.opacity(0.12)))

                VStack(alignment: .leading, spacing: 7) {
                    Text("Connect your Garmin Edge to get started.")
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Once connected, scan for recordings, import one, then convert it to MP4.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    mtp.scanRecordings()
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(mtp.isScanningRecordings)
            }
        }
    }

    private var storageSummaryCard: some View {
        DashboardCard(title: "Storage", symbol: "internaldrive") {
            VStack(alignment: .leading, spacing: 10) {
                Text(storageFreeText)
                    .font(.title3.weight(.semibold))

                if mtp.storageFreeGB != nil {
                    ProgressView(value: 1.0)
                        .tint(.green)
                    Text("Free space reported by the connected Garmin.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Storage appears after a Garmin scan reports available space.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var recordingsSummaryCard: some View {
        DashboardCard(title: "Recordings", symbol: "folder") {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(mtp.recordings.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text(mtp.recordings.isEmpty ? "No recordings discovered yet." : "Recordings discovered on your Garmin.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button {
                    sidebarSelection = .recordings
                } label: {
                    Label("Browse", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.bordered)
                .disabled(mtp.isImporting)
            }
        }
    }

    private var importSummaryCard: some View {
        DashboardCard(title: "Imported Recording", symbol: "arrow.down.circle") {
            VStack(alignment: .leading, spacing: 10) {
                Text(mtp.importComplete ? "Ready to Convert" : "Waiting")
                    .font(.title3.weight(.semibold))

                Text(mtp.importComplete ? "\(mtp.importedFileCount) frames imported." : "Import one recording to prepare MP4 conversion.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if mtp.importComplete {
                    Button {
                        sidebarSelection = .convert
                    } label: {
                        Label("Continue to Convert", systemImage: "film")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var recentActivityPanel: some View {
        DashboardCard(title: "Recent Activity", symbol: "clock") {
            VStack(alignment: .leading, spacing: 8) {
                if mtp.recentActivity.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Imports and conversions will appear here during this session.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                } else {
                    ForEach(mtp.recentActivity) { item in
                        MetricStatusRow(
                            title: item.message,
                            detail: item.timeText,
                            systemImage: "checkmark.circle.fill",
                            tint: .green
                        )
                    }
                }
            }
        }
    }

    // MARK: - Devices

    private var devicesScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader(
                    title: "Devices",
                    subtitle: mtp.deviceConnected ? "Inspect the connected Garmin device." : "Connect a compatible Garmin Edge device.",
                    symbol: "externaldrive.connected.to.line.below",
                    badge: deviceConnectionBadge
                )

                if mtp.deviceConnected {
                    connectedDeviceHero
                } else {
                    deviceDisconnectedPanel
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    DashboardCard(title: "Device", symbol: "externaldrive") {
                        VStack(spacing: 10) {
                            MetricStatusRow(title: "Model", detail: mtp.deviceName, systemImage: "display", tint: .blue)
                            MetricStatusRow(title: "Connection", detail: "Garmin Connection", systemImage: "cable.connector.horizontal", tint: .green)
                            MetricStatusRow(title: "Status", detail: mtp.deviceConnected ? "Connected" : "Not Connected", systemImage: mtp.deviceConnected ? "checkmark.circle.fill" : "circle", tint: mtp.deviceConnected ? .green : Color(nsColor: .secondaryLabelColor))
                        }
                    }

                    DashboardCard(title: "Storage", symbol: "internaldrive") {
                        VStack(alignment: .leading, spacing: 12) {
                            MetricStatusRow(title: "Available", detail: storageFreeText, systemImage: "internaldrive", tint: mtp.storageFreeGB == nil ? Color(nsColor: .secondaryLabelColor) : .green)
                            if mtp.storageFreeGB != nil {
                                ProgressView(value: 1.0)
                                    .tint(.green)
                            }
                            Text(mtp.storageFreeGB == nil ? "Storage is shown when the Garmin reports free space during scan." : "Free space reported by the connected device.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    DashboardCard(title: "Connection", symbol: "network") {
                        VStack(spacing: 10) {
                            MetricStatusRow(title: "Device Communication", detail: mtp.deviceConnected ? "Ready" : "Waiting", systemImage: mtp.deviceConnected ? "checkmark.circle.fill" : "clock", tint: mtp.deviceConnected ? .green : .orange)
                            MetricStatusRow(title: "Scan", detail: mtp.isScanningRecordings ? (mtp.scanStatus.isEmpty ? "Scanning" : mtp.scanStatus) : "Idle", systemImage: mtp.isScanningRecordings ? "arrow.triangle.2.circlepath" : "checkmark.circle", tint: mtp.isScanningRecordings ? .blue : .green)
                            MetricStatusRow(title: "Recordings", detail: "\(mtp.recordings.count)", systemImage: "folder", tint: .blue)
                        }
                    }

                    DashboardCard(title: "Actions", symbol: "bolt") {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                mtp.scanRecordings()
                            } label: {
                                Label(mtp.isScanningRecordings ? "Scanning…" : "Scan Recordings", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(mtp.isScanningRecordings)

                            Button {
                                sidebarSelection = .recordings
                            } label: {
                                Label("Open Recordings", systemImage: "list.bullet.rectangle")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var deviceDisconnectedPanel: some View {
        DashboardCard(title: "No Garmin Connected", symbol: "externaldrive.badge.questionmark") {
            HStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.questionmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.softCardBackground))

                VStack(alignment: .leading, spacing: 4) {
                    Text("No Garmin Connected")
                        .font(.headline)
                    Text("Connect your Garmin Edge, then scan for recordings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    mtp.scanRecordings()
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(mtp.isScanningRecordings)
            }
        }
    }

    private var deviceConnectionBadge: StatusBadge {
        StatusBadge(
            title: mtp.deviceConnected ? "Connected" : "Not Connected",
            systemImage: mtp.deviceConnected ? "checkmark.circle.fill" : "circle",
            style: mtp.deviceConnected ? .healthy : .neutral
        )
    }

    // MARK: - Recordings

    private var recordingsScreen: some View {
        VStack(spacing: 0) {
            recordingsHeader

            Divider()

            recordingsContent

            Divider()

            recordingsActionBar
        }
        .background(Color.panelBackground)
        .onAppear {
            if mtp.recordings.isEmpty && !mtp.isScanningRecordings {
                mtp.scanRecordings()
            }
        }
    }

    private var recordingsHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.blue.opacity(0.12)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recordings")
                        .font(.system(size: 30, weight: .bold))
                    Text("Browse screen recordings stored on your Garmin Edge.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    mtp.scanRecordings()
                } label: {
                    Label(mtp.isScanningRecordings ? "Scanning…" : "Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(mtp.isScanningRecordings || mtp.isImporting)
            }

            HStack(spacing: 10) {
                Label(mtp.deviceConnected ? mtp.deviceName : "No Garmin Connected", systemImage: mtp.deviceConnected ? "externaldrive.connected.to.line.below" : "externaldrive.badge.questionmark")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(mtp.deviceConnected ? .primary : .secondary)
                Spacer()
                StatusBadge(
                    title: mtp.deviceConnected ? "Connected" : "Waiting for Device",
                    systemImage: mtp.deviceConnected ? "checkmark.circle.fill" : "clock",
                    style: mtp.deviceConnected ? .healthy : .neutral
                )
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.elevatedCardBackground))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.cardBorder))
        }
        .padding(24)
    }

    @ViewBuilder
    private var recordingsContent: some View {
        if mtp.isScanningRecordings {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text(mtp.scanStatus.isEmpty ? "Scanning recordings…" : mtp.scanStatus)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if mtp.recordings.isEmpty {
            ContentUnavailableView(
                mtp.deviceConnected ? "No Recordings Found" : "No Garmin Connected",
                systemImage: mtp.deviceConnected ? "folder.badge.questionmark" : "externaldrive.badge.questionmark",
                description: Text(mtp.deviceConnected ? "Refresh to scan the connected Garmin again." : "Connect your Garmin Edge, then refresh.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(recordingSections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 2)

                            VStack(spacing: 0) {
                                ForEach(section.recordings) { recording in
                                    RecordingRow(
                                        recording: recording,
                                        isSelected: selectedRecordingIDs.contains(recording.id),
                                        isImporting: mtp.isImporting,
                                        action: { toggleRecordingSelection(recording) }
                                    )
                                    if recording.id != section.recordings.last?.id {
                                        Divider().padding(.leading, 54)
                                    }
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.elevatedCardBackground))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.cardBorder))
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    private var recordingsActionBar: some View {
        VStack(spacing: 0) {
            if mtp.isImporting || mtp.importComplete {
                importStateStrip
                Divider()
            }

            HStack(spacing: 12) {
                Text(selectionSummaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedRecordingIDs.isEmpty || mtp.isImporting)

                Button {
                    importSelectedRecording()
                } label: {
                    Label(mtp.isImporting ? "Importing…" : "Import Selected", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedRecordingIDs.count != 1 || mtp.isImporting)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.elevatedCardBackground.opacity(0.86))
        }
    }

    private var importStateStrip: some View {
        HStack(spacing: 12) {
            if mtp.isImporting {
                ProgressView(value: mtp.importProgress)
                    .frame(width: 120)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Importing Recording")
                        .font(.callout.weight(.semibold))
                    Text(mtp.importStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else if mtp.importComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Complete")
                        .font(.callout.weight(.semibold))
                    Text("\(mtp.importedFileCount) frames imported from \(mtp.latestRecordingFolderName).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if mtp.importComplete {
                Button {
                    sidebarSelection = .convert
                } label: {
                    Label("Continue to Convert", systemImage: "film")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.softCardBackground.opacity(0.9))
    }

    // MARK: - Phase 3 destination placeholders

    private var convertScreen: some View {
        placeholderScreen(
            title: "Convert",
            subtitle: "Turn your imported recording into an MP4 ready to edit or share.",
            symbol: "film"
        ) {
            conversionPanel
        }
    }

    private var diagnosticsScreen: some View {
        placeholderScreen(
            title: "Diagnostics",
            subtitle: "System health and support export using the existing diagnostics report.",
            symbol: "stethoscope"
        ) {
            DashboardCard(title: "System Health", symbol: "checkmark.seal") {
                VStack(spacing: 10) {
                    MetricStatusRow(
                        title: "Garmin Device",
                        detail: mtp.deviceConnected ? mtp.deviceName : "Not connected",
                        systemImage: mtp.deviceConnected ? "checkmark.circle.fill" : "circle",
                        tint: mtp.deviceConnected ? .green : Color(nsColor: .secondaryLabelColor)
                    )
                    MetricStatusRow(
                        title: "Device Communication",
                        detail: mtp.deviceConnected ? "Ready" : "Waiting for Garmin",
                        systemImage: mtp.deviceConnected ? "checkmark.circle.fill" : "exclamationmark.circle",
                        tint: mtp.deviceConnected ? .green : .orange
                    )
                    MetricStatusRow(
                        title: "Video Conversion",
                        detail: FileManager.default.fileExists(atPath: FFmpegRunner.ffmpegPath) ? "Ready" : "Unavailable",
                        systemImage: FileManager.default.fileExists(atPath: FFmpegRunner.ffmpegPath) ? "checkmark.circle.fill" : "xmark.circle.fill",
                        tint: FileManager.default.fileExists(atPath: FFmpegRunner.ffmpegPath) ? .green : .red
                    )
                    MetricStatusRow(
                        title: "Beta Status",
                        detail: "\(betaAccess.daysRemaining) days remaining",
                        systemImage: betaAccess.hasValidAccess ? "checkmark.circle.fill" : "exclamationmark.circle",
                        tint: betaAccess.hasValidAccess ? .green : .orange
                    )
                }
            }

            Button {
                exportDiagnostics()
            } label: {
                Label("Run Full Diagnostics", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var betaUpdatesScreen: some View {
        placeholderScreen(
            title: "Beta & Updates",
            subtitle: "Beta access and update configuration from the current app bundle.",
            symbol: "clock.badge.checkmark"
        ) {
            DashboardCard(title: "Beta Access", symbol: "checkmark.seal") {
                VStack(spacing: 10) {
                    MetricStatusRow(
                        title: "Status",
                        detail: betaAccess.hasValidAccess ? "Active" : "Inactive",
                        systemImage: betaAccess.hasValidAccess ? "checkmark.circle.fill" : "xmark.circle.fill",
                        tint: betaAccess.hasValidAccess ? .green : .red
                    )
                    MetricStatusRow(title: "Days Remaining", detail: "\(betaAccess.daysRemaining)", systemImage: "calendar", tint: .blue)
                    MetricStatusRow(title: "Activation Date", detail: betaAccess.activationDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Not available", systemImage: "clock", tint: Color(nsColor: .secondaryLabelColor))
                    MetricStatusRow(title: "Expiry Date", detail: betaAccess.expiryDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Not available", systemImage: "calendar.badge.clock", tint: Color(nsColor: .secondaryLabelColor))
                }
            }

            DashboardCard(title: "Sparkle Updates", symbol: "arrow.triangle.2.circlepath") {
                VStack(spacing: 10) {
                    MetricStatusRow(title: "Current Version", detail: appVersionText, systemImage: "app", tint: .blue)
                    MetricStatusRow(title: "Current Build", detail: buildNumberText, systemImage: "number", tint: .blue)
                    Text("Use Garmin Screen Studio > Check for Updates… from the app menu. Sparkle wiring remains unchanged in Phase 2.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var settingsScreen: some View {
        placeholderScreen(
            title: "Settings",
            subtitle: "Open the native Settings window for current app preferences.",
            symbol: "gearshape"
        ) {
            DashboardCard(title: "Preferences", symbol: "gearshape") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No additional settings are introduced in Phase 2.")
                        .foregroundStyle(.secondary)
                    Button {
                        openSettings()
                    } label: {
                        Label("Open Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func placeholderScreen<Content: View>(
        title: String,
        subtitle: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader(title: title, subtitle: subtitle, symbol: symbol)
                content()
            }
            .padding(24)
        }
    }

    private func pageHeader(title: String, subtitle: String, symbol: String, badge: StatusBadge? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.blue.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let badge {
                badge
            }
        }
    }

    private var conversionPanel: some View {
        DashboardCard(title: "Convert to MP4", symbol: "film") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    StatusBadge(
                        title: conversionStatusText,
                        systemImage: mtp.conversionComplete ? "checkmark.circle.fill" : (mtp.isConverting ? "arrow.triangle.2.circlepath" : "circle"),
                        style: mtp.conversionComplete ? .healthy : (mtp.isConverting ? .working : .neutral)
                    )
                    Spacer()
                    Button {
                        mtp.convertToVideo()
                    } label: {
                        Text(mtp.isConverting ? "Converting…" : "Convert")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!mtp.importComplete || mtp.isConverting)
                }

                Divider()

                VStack(spacing: 10) {
                    MetricStatusRow(title: "Source", detail: mtp.latestRecordingFolderName.isEmpty ? "No recording imported" : mtp.latestRecordingFolderName, systemImage: "folder", tint: .blue)
                    MetricStatusRow(title: "Frames", detail: "\(mtp.importedImageURLs.count)", systemImage: "photo", tint: .blue)
                    MetricStatusRow(title: "Dimensions", detail: mtp.latestRecordingDimensions.isEmpty ? "Unavailable" : mtp.latestRecordingDimensions, systemImage: "aspectratio", tint: Color(nsColor: .secondaryLabelColor))
                    MetricStatusRow(title: "Output", detail: "~/Movies/Garmin Screen Studio", systemImage: "internaldrive", tint: Color(nsColor: .secondaryLabelColor))
                }

                if let video = mtp.outputVideo {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([video])
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Recording Actions

    private func toggleRecordingSelection(_ recording: GarminRecording) {
        if selectedRecordingIDs.contains(recording.id) {
            selectedRecordingIDs.remove(recording.id)
        } else {
            selectedRecordingIDs.insert(recording.id)
        }
    }

    private func importSelectedRecording() {
        guard selectedRecordingIDs.count == 1,
              let id = selectedRecordingIDs.first,
              let recording = mtp.recordings.first(where: { $0.id == id }) else { return }
        mtp.importRecording(recording)
    }

    private func deleteSelectedRecordings() {
        let toDelete = mtp.recordings.filter { selectedRecordingIDs.contains($0.id) }
        mtp.deleteRecordings(toDelete)
        selectedRecordingIDs.removeAll()
    }

    // MARK: - Actions

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func exportDiagnostics() {
        let report = DiagnosticsReport.generateReport(mtpManager: mtp)

        let panel = NSSavePanel()
        panel.title = "Export Diagnostics Report"
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = diagnosticsFilename()

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                Logger.info("Diagnostics export cancelled")
                return
            }

            do {
                try report.write(to: url, atomically: true, encoding: .utf8)
                Logger.success("Diagnostics report exported to \(url.path)")
            } catch {
                Logger.error("Diagnostics export failed: \(error.localizedDescription)")
            }
        }
    }

    private func diagnosticsFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "GarminScreenStudio-Diagnostics-\(formatter.string(from: Date())).txt"
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private var appVersionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var buildNumberText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }

    private var storageFreeText: String {
        mtp.storageFreeGB.map { String(format: "%.1f GB free", $0) } ?? "Unavailable"
    }

    private var conversionStatusText: String {
        if mtp.conversionComplete { return "Video Ready" }
        if mtp.isConverting { return "Converting" }
        if mtp.importComplete { return "Ready" }
        return "Waiting for Import"
    }

    private var selectionSummaryText: String {
        if selectedRecordingIDs.isEmpty { return "No recording selected" }
        if selectedRecordingIDs.count == 1 { return "1 recording selected" }
        return "\(selectedRecordingIDs.count) recordings selected"
    }

    private var recordingSections: [RecordingDateSection] {
        let calendar = Calendar.current
        let today = mtp.recordings.filter { recording in
            guard let date = recording.date else { return false }
            return calendar.isDateInToday(date)
        }
        let yesterday = mtp.recordings.filter { recording in
            guard let date = recording.date else { return false }
            return calendar.isDateInYesterday(date)
        }
        let earlier = mtp.recordings.filter { recording in
            guard let date = recording.date else { return true }
            return !calendar.isDateInToday(date) && !calendar.isDateInYesterday(date)
        }

        return [
            RecordingDateSection(id: "today", title: "Today", recordings: today),
            RecordingDateSection(id: "yesterday", title: "Yesterday", recordings: yesterday),
            RecordingDateSection(id: "earlier", title: "Earlier", recordings: earlier)
        ].filter { !$0.recordings.isEmpty }
    }
}

private struct DashboardCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.cardBorder)
        )
    }
}

private struct DeviceHeroCard<Metrics: View, Actions: View>: View {
    let title: String
    let subtitle: String
    let status: String
    let statusStyle: StatusBadge.Style
    @ViewBuilder var metrics: Metrics
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.linearGradient(colors: [.blue.opacity(0.18), .cyan.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 94, height: 118)

                Image(systemName: "display")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 28, weight: .bold))
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    StatusBadge(title: status, systemImage: "checkmark.circle.fill", style: statusStyle)
                }

                HStack(spacing: 14) {
                    metrics
                }
            }

            VStack(alignment: .trailing, spacing: 10) {
                actions
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.18))
        )
    }
}

private struct DeviceMetric: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue.opacity(0.12)))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.callout.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.softCardBackground))
    }
}

private struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color
    var isDisabled = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(accent.opacity(isHovering ? 0.18 : 0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isHovering ? accent : Color(nsColor: .tertiaryLabelColor))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovering ? Color.softCardBackground : Color.elevatedCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isHovering ? accent.opacity(0.26) : Color.cardBorder)
            )
            .scaleEffect(isHovering && !reduceMotion ? 1.01 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .onHover { hovering in
            guard !isDisabled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
    }
}

private struct RecordingRow: View {
    let recording: GarminRecording
    let isSelected: Bool
    let isImporting: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 24)

                Image(systemName: "film.stack")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.blue.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(recording.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(recording.dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(recording.imageCount) frames")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("Est. \(recording.durationText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isImporting)
    }
}

private struct StatusBadge: View {
    enum Style {
        case healthy
        case working
        case warning
        case neutral

        var color: Color {
            switch self {
            case .healthy: .green
            case .working: .blue
            case .warning: .orange
            case .neutral: Color(nsColor: .secondaryLabelColor)
            }
        }
    }

    let title: String
    let systemImage: String
    let style: Style

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(style.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(style.color.opacity(0.12)))
            .accessibilityLabel(title)
    }
}

private struct MetricStatusRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)

            Text(title)
                .font(.callout.weight(.medium))

            Spacer()

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
