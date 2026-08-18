import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

// MARK: - Palette

extension Color {
    static let panelBackground = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .controlBackgroundColor)
    static let cardBackground = Color(nsColor: .underPageBackgroundColor)
    static let cardBorder = Color(nsColor: .separatorColor).opacity(0.45)
    static let brandStroke = Color(nsColor: .labelColor)
    static let brandIcon = Color(nsColor: .labelColor)
}

struct ContentView: View {

    @StateObject private var mtp = MTPManager()
    @StateObject private var betaAccess = BetaAccessManager()
    @State private var showRecordingBrowser = false

    var body: some View {
        mainContent
    }

    @ViewBuilder
    private var mainContent: some View {
        if betaAccess.hasValidAccess {
            applicationContent
        } else {
            BetaActivationView(betaAccess: betaAccess)
                .frame(width: 1180, height: 760)
        }
    }

    private var applicationContent: some View {

        HStack(spacing: 0) {

            sidebar
                .frame(width: 260)
                .background(Color.sidebarBackground)

            Divider().background(Color.cardBorder)

            dashboardContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.panelBackground)

        }
        .frame(width: 1180, height: 760)
        .sheet(isPresented: $showRecordingBrowser) {
            RecordingBrowserView(mtp: mtp)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {

        VStack(alignment: .leading, spacing: 22) {

            HStack(spacing: 12) {

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.brandStroke, lineWidth: 1.5)
                        .frame(width: 48, height: 48)

                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.brandIcon)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Garmin")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Screen Studio")
                        .font(.system(size: 14, weight: .semibold))
                    Text("v1.1")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.top, 20)

            sectionLabel("DEVICE")
            deviceCard

            sectionLabel("ACTIONS")
            actionsSection

            sectionLabel("RECENT ACTIVITY")
            recentActivitySection

            Spacer()

            betaStatus

            footerLink

        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
    }

    private var deviceCard: some View {

        HStack(spacing: 10) {

            Circle()
                .fill(mtp.deviceConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(mtp.deviceConnected ? mtp.deviceName : "No Device")
                    .font(.system(size: 13, weight: .medium))

                Text(mtp.deviceConnected ? "Connected" : "Not connected")
                    .font(.caption2)
                    .foregroundStyle(mtp.deviceConnected ? .green : .secondary)

                if let free = mtp.storageFreeGB {
                    Text(String(format: "Storage: %.1f GB free", free))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "iphone")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.cardBorder))
    }

    private var actionsSection: some View {

        VStack(spacing: 6) {

            actionRow(
                icon: "list.bullet.rectangle",
                title: "Browse Recordings",
                subtitle: "Choose a recording to import",
                highlighted: true,
                disabled: mtp.isImporting
            ) {
                showRecordingBrowser = true
            }

            actionRow(
                icon: "folder",
                title: "Open Movies Folder",
                subtitle: "View converted videos"
            ) {
                let moviesFolder = URL(fileURLWithPath: NSHomeDirectory() + "/Movies/Garmin Screen Studio")

                // On a fresh install this folder doesn't exist yet (it's
                // only created the first time a recording is imported or
                // converted), so on a tester's Mac this action would
                // silently fail. Create it on demand so the action always
                // has something valid to open.
                do {
                    try FileManager.default.createDirectory(
                        at: moviesFolder,
                        withIntermediateDirectories: true
                    )
                } catch {
                    Logger.error("Failed to create Movies folder at \(moviesFolder.path): \(error.localizedDescription)")
                }

                NSWorkspace.shared.open(moviesFolder)
            }

            actionRow(
                icon: "arrow.down.doc.fill",
                title: "Convert to MP4",
                subtitle: "Create a video file",
                disabled: !mtp.importComplete || mtp.isConverting
            ) {
                mtp.convertToVideo()
            }

            actionRow(
                icon: "gearshape.fill",
                title: "Settings",
                subtitle: "App preferences"
            ) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            // Temporary — Stage 3 of the diagnostics system.
            actionRow(
                icon: "square.and.arrow.up",
                title: "Export Diagnostics",
                subtitle: "Save a report for support"
            ) {
                exportDiagnostics()
            }

        }
    }

    private func actionRow(
        icon: String,
        title: String,
        subtitle: String,
        highlighted: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            HStack(spacing: 12) {

                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(highlighted ? .white.opacity(0.75) : .secondary)
                }

                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(highlighted ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.4 : 1)
        .disabled(disabled)
    }

    private var recentActivitySection: some View {

        VStack(alignment: .leading, spacing: 8) {

            if mtp.recentActivity.isEmpty {

                Text("Nothing yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            } else {

                ForEach(mtp.recentActivity) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)

                        Text(item.message)
                            .font(.system(size: 12))
                            .lineLimit(1)

                        Spacer()

                        Text(item.timeText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var betaStatus: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text("Beta • \(betaAccess.daysRemaining) days remaining")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var footerLink: some View {

        Link(destination: URL(string: "https://www.youtube.com/@CyclingwithRuss")!) {
            HStack(spacing: 6) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.red)

                Text("Built by Cycling with Russ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    // MARK: - Main content

    private var dashboardContent: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                importProgressCard

                statsRow

                HStack(alignment: .top, spacing: 20) {
                    latestRecordingCard
                        .frame(maxWidth: .infinity)

                    importedFilesCard
                        .frame(maxWidth: .infinity)
                }

                conversionCard

            }
            .padding(24)
        }
    }

    private var importProgressCard: some View {

        VStack(alignment: .leading, spacing: 14) {

            Text("IMPORT PROGRESS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)

            HStack(spacing: 12) {

                Image(systemName: mtp.importComplete ? "checkmark.circle.fill" : (mtp.isImporting ? "arrow.triangle.2.circlepath" : "circle"))
                    .font(.system(size: 22))
                    .foregroundStyle(mtp.importComplete ? .green : (mtp.isImporting ? .blue : .secondary))
                    .rotationEffect(.degrees(mtp.isImporting ? 360 : 0))
                    .animation(
                        mtp.isImporting ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: mtp.isImporting
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(mtp.importComplete ? "Import Complete!" : mtp.importStatus)
                        .font(.system(size: 18, weight: .bold))

                    if mtp.importComplete {
                        Text("\(mtp.importedFileCount) files imported from \(mtp.latestRecordingFolderName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if mtp.isImporting {
                    Text("\(Int(mtp.importProgress * 100))%")
                        .font(.system(size: 16, weight: .bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if mtp.isImporting || mtp.importComplete {
                ProgressView(value: mtp.importProgress)
                    .tint(mtp.importComplete ? .green : .blue)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardBorder))
    }

    private var statsRow: some View {

        HStack(spacing: 16) {

            statCard(icon: "folder.fill", color: .blue, value: "\(mtp.importedFileCount)", label: "Files Imported")
            statCard(icon: "photo.fill", color: .blue, value: "\(mtp.importedImageURLs.count)", label: "Images (BMP)")
            statCard(icon: "clock.fill", color: .blue, value: mtp.importDurationText, label: "Import Time")
            statCard(icon: "externaldrive.fill", color: .blue, value: mtp.dataImportedText, label: "Data Imported")
        }
    }

    private func statCard(icon: String, color: Color, value: String, label: String) -> some View {

        HStack(spacing: 12) {

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.18))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.cardBorder))
    }

    private var latestRecordingCard: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("LATEST RECORDING")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)

            if let last = mtp.importedImageURLs.last {

                thumbnail(for: last)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {

                    if let date = mtp.latestRecordingDate {
                        metaRow(icon: "calendar", text: date.formatted(date: .long, time: .shortened))
                    }

                    metaRow(
                        icon: "folder",
                        text: mtp.latestRecordingFolderName.isEmpty
                            ? "Movies/Garmin Screen Studio/Latest Recording"
                            : mtp.latestRecordingFolderName
                    )

                    if !mtp.latestRecordingDimensions.isEmpty {
                        metaRow(icon: "aspectratio", text: mtp.latestRecordingDimensions)
                    }

                    metaRow(icon: "internaldrive", text: mtp.dataImportedText)
                }
                .padding(.top, 4)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([last])
                } label: {
                    Text("Show in Finder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

            } else {

                VStack {
                    Spacer()
                    Text("No recording imported yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 160)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardBorder))
    }

    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var importedFilesCard: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text("IMPORTED FILES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                Spacer()

                if !mtp.importedImageURLs.isEmpty {
                    Text("\(mtp.importedImageURLs.count)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue))
                }
            }

            if mtp.importedImageURLs.isEmpty {

                VStack {
                    Spacer()
                    Text("No files yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 160)

            } else {

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {

                    ForEach(Array(mtp.importedImageURLs.prefix(8)), id: \.self) { url in

                        VStack(alignment: .leading, spacing: 4) {

                            thumbnail(for: url)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 70)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .clipped()

                            Text(url.lastPathComponent)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardBorder))
    }

    private var conversionCard: some View {

        VStack(alignment: .leading, spacing: 14) {

            Text("CONVERSION")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)

            HStack(spacing: 14) {

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "film.fill")
                        .foregroundStyle(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {

                    Text("Convert to MP4")
                        .font(.system(size: 15, weight: .semibold))

                    if mtp.conversionComplete {
                        Text("Video ready")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if mtp.isConverting {
                        Text("Converting…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if mtp.importComplete {
                        Text("Ready to convert \(mtp.importedImageURLs.count) images to video")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Estimated time: \(mtp.estimatedConversionTimeText)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Import a recording first")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    mtp.convertToVideo()
                } label: {
                    Text(mtp.isConverting ? "Converting…" : "Convert to MP4")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!mtp.importComplete || mtp.isConverting)
            }

            Divider().background(Color.cardBorder)

            HStack {

                VStack(alignment: .leading, spacing: 2) {
                    Text("OUTPUT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("~/Movies/Garmin Screen Studio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !mtp.conversionComplete {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ESTIMATED SIZE")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(mtp.estimatedConversionSizeText)
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
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
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardBorder))
    }

    // MARK: - Diagnostics export (temporary — Stage 3)

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

    private func thumbnail(for url: URL) -> Image {
        if let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "photo")
    }
}

#Preview {
    ContentView()
}
