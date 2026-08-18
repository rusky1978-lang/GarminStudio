import SwiftUI
import AppKit

struct ConvertView: View {
    @ObservedObject var mtp: MTPManager
    let browseRecordings: () -> Void
    let exportDiagnostics: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PhasePageHeader(
                    title: "Convert to MP4",
                    subtitle: "Turn your imported Garmin recording into an MP4 ready to edit or share.",
                    symbol: "film"
                ) {
                    conversionBadge
                }

                if !mtp.importComplete && !mtp.isImporting {
                    noRecordingReadyState
                } else {
                    conversionWorkflow
                }
            }
            .padding(24)
        }
        .background(Color.panelBackground)
        .animation(.easeInOut(duration: 0.2), value: mtp.conversionComplete)
    }

    private var conversionBadge: some View {
        if mtp.isConverting {
            StudioStatusBadge(title: "Converting", systemImage: "arrow.triangle.2.circlepath", style: .working)
        } else if mtp.conversionComplete {
            StudioStatusBadge(title: "Complete", systemImage: "checkmark.circle.fill", style: .healthy)
        } else if mtp.importComplete {
            StudioStatusBadge(title: "Ready", systemImage: "checkmark.circle", style: .healthy)
        } else {
            StudioStatusBadge(title: "Waiting for Import", systemImage: "circle", style: .neutral)
        }
    }

    private var noRecordingReadyState: some View {
        StudioCard(title: "No Recording Ready", symbol: "folder.badge.questionmark", prominence: .soft) {
            HStack(spacing: 18) {
                Image(systemName: "film.stack")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 66, height: 66)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.blue.opacity(0.12)))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Import a recording from your Garmin before converting.")
                        .font(.title3.weight(.semibold))
                    Text("The import workflow prepares your recording so it can be turned into a shareable video.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    browseRecordings()
                } label: {
                    Label("Browse Recordings", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var conversionWorkflow: some View {
        VStack(alignment: .leading, spacing: 16) {
            if mtp.isConverting {
                conversionProgressCard
            } else if mtp.conversionComplete {
                conversionCompleteCard
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                sourceCard
                outputCard
            }

            actionCard
        }
    }

    private var sourceCard: some View {
        StudioCard(title: "Source", symbol: "folder") {
            HStack(alignment: .top, spacing: 16) {
                sourcePreview

                VStack(spacing: 9) {
                    StudioMetricRow(title: "Recording", detail: mtp.latestRecordingFolderName.isEmpty ? "Imported recording" : mtp.latestRecordingFolderName, systemImage: "folder", tint: .blue)
                    StudioMetricRow(title: "Frames", detail: "\(mtp.importedImageURLs.count)", systemImage: "photo", tint: .blue)
                    StudioMetricRow(title: "Resolution", detail: mtp.latestRecordingDimensions.isEmpty ? "Unavailable" : mtp.latestRecordingDimensions, systemImage: "aspectratio", tint: Color(nsColor: .secondaryLabelColor))
                    StudioMetricRow(title: "Imported", detail: mtp.latestRecordingDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "This session", systemImage: "clock", tint: Color(nsColor: .secondaryLabelColor))
                    StudioMetricRow(title: "Size", detail: mtp.dataImportedText, systemImage: "externaldrive", tint: Color(nsColor: .secondaryLabelColor))
                    StudioMetricRow(title: "Import Time", detail: mtp.importDurationText, systemImage: "timer", tint: Color(nsColor: .secondaryLabelColor))
                }
            }
        }
    }

    private var sourcePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.softCardBackground)
                .frame(width: 128, height: 92)

            if let firstImage = mtp.importedImageURLs.first,
               let image = NSImage(contentsOf: firstImage) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .frame(width: 118, height: 82)
            } else {
                Image(systemName: "film.stack")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.blue)
            }
        }
        .accessibilityLabel("Imported recording preview")
    }

    private var outputCard: some View {
        StudioCard(title: "Output", symbol: "square.and.arrow.up") {
            VStack(alignment: .leading, spacing: 12) {
                StudioMetricRow(title: "Video Type", detail: "MP4", systemImage: "film", tint: .blue)
                StudioMetricRow(title: "Destination", detail: "~/Movies/Garmin Screen Studio", systemImage: "internaldrive", tint: Color(nsColor: .secondaryLabelColor))
                StudioMetricRow(title: "Output", detail: mtp.outputVideo?.lastPathComponent ?? outputNameText, systemImage: "doc", tint: Color(nsColor: .secondaryLabelColor))
                StudioMetricRow(title: "Estimated Size", detail: mtp.estimatedConversionSizeText, systemImage: "externaldrive", tint: Color(nsColor: .secondaryLabelColor))
                StudioMetricRow(title: "Estimated Time", detail: mtp.estimatedConversionTimeText, systemImage: "timer", tint: Color(nsColor: .secondaryLabelColor))

                HStack(spacing: 10) {
                    Button {
                        openOutputFolder()
                    } label: {
                        Label("Open Movies Folder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)

                    if let video = mtp.outputVideo {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([video])
                        } label: {
                            Label("Show in Finder", systemImage: "scope")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var conversionProgressCard: some View {
        StudioCard(title: "Conversion In Progress", symbol: "arrow.triangle.2.circlepath", prominence: .soft) {
            HStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Converting imported frames")
                        .font(.headline)
                    Text(mtp.latestRecordingFolderName.isEmpty ? "Creating your MP4." : "Processing \(mtp.latestRecordingFolderName)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var conversionCompleteCard: some View {
        StudioCard(title: "Conversion Complete", symbol: "checkmark.circle.fill", prominence: .soft) {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your MP4 is ready")
                        .font(.headline)
                    Text(mtp.outputVideo?.lastPathComponent ?? "Saved to the Movies folder.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let video = mtp.outputVideo {
                    Button {
                        NSWorkspace.shared.open(video)
                    } label: {
                        Label("Open Video", systemImage: "play.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    browseRecordings()
                } label: {
                    Label("Convert Another", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var actionCard: some View {
        StudioCard(title: "Convert", symbol: "bolt") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(actionTitle)
                        .font(.headline)
                    Text(actionSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    mtp.convertToVideo()
                } label: {
                    Label(mtp.isConverting ? "Converting…" : "Convert to MP4", systemImage: "film")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!mtp.importComplete || mtp.isConverting)

                Button {
                    exportDiagnostics()
                } label: {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var actionTitle: String {
        if mtp.isConverting { return "Conversion is running" }
        if mtp.conversionComplete { return "Convert again if needed" }
        return "Ready to create MP4"
    }

    private var actionSubtitle: String {
        if mtp.isConverting { return "Keep Garmin Screen Studio open until the process completes." }
        return "Uses the current Garmin Screen Studio conversion workflow."
    }

    private var outputNameText: String {
        if mtp.latestRecordingFolderName.isEmpty {
            return "Generated MP4"
        }
        return "\(mtp.latestRecordingFolderName).mp4"
    }

    private func openOutputFolder() {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies")
            .appendingPathComponent("Garmin Screen Studio")
        NSWorkspace.shared.open(folder)
    }
}
