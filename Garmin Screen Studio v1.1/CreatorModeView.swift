import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers

/// Milestone 1 + 2 + 3 of Creator Mode: import camera footage, manually
/// sync it against a Garmin recording, then export a basic
/// Picture-in-Picture MP4 (camera full-frame, Garmin small corner).
struct CreatorModeView: View {

    @ObservedObject var mtp: MTPManager
    @Environment(\.dismiss) private var dismiss

    @State private var garminSource: GarminRecordingSource?
    @State private var cameraSources: [CameraSource] = []

    @State private var syncingCameraID: UUID?

    var body: some View {

        VStack(spacing: 0) {

            header

            Divider()

            content

            Divider()

            footer
        }
        .frame(width: 720, height: 520)
        .onAppear {
            refreshGarminSourceFromFreshConversion()
        }
        .onChange(of: mtp.outputVideo) { _, _ in
            refreshGarminSourceFromFreshConversion()
        }
        .sheet(item: syncingCameraBinding) { camera in
            if let garminSource {
                SyncView(
                    garminURL: garminSource.url,
                    cameraURL: camera.url,
                    initialOffset: camera.syncOffset
                ) { newOffset in
                    updateSyncOffset(for: camera.id, offset: newOffset)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Creator Mode")
                    .font(.headline)
                Text("Beta — import, sync, and export a Picture-in-Picture video")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") { dismiss() }
        }
        .padding(16)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                VStack(alignment: .leading, spacing: 10) {

                    HStack {
                        Text("GARMIN RECORDING")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)

                        Spacer()

                        Button {
                            importGarminRecording()
                        } label: {
                            Text(garminSource == nil ? "Select Garmin Video…" : "Change…")
                                .font(.caption)
                        }
                        .buttonStyle(.link)
                    }

                    if let garminSource {
                        sourceCard(
                            name: garminSource.displayName,
                            duration: garminSource.duration,
                            thumbnail: garminSource.thumbnail,
                            trailing: AnyView(EmptyView())
                        )
                    } else {
                        Text("Convert a recording this session (Browse Recordings → Convert to MP4), or click \"Select Garmin Video…\" above to use one you already made.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {

                    Text("CAMERA FOOTAGE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)

                    if cameraSources.isEmpty {
                        Text("No camera footage imported yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(cameraSources) { source in
                            cameraCard(for: source)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func cameraCard(for source: CameraSource) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            sourceCard(
                name: source.displayName,
                duration: source.duration,
                thumbnail: source.thumbnail,
                trailing: AnyView(syncButton(for: source))
            )

            if source.isSynced {

                HStack(spacing: 10) {

                    Button {
                        exportPiP(for: source)
                    } label: {
                        Label(source.isExporting ? "Exporting…" : "Export PiP…", systemImage: "rectangle.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(source.isExporting || garminSource == nil)

                    if source.isExporting {
                        ProgressView(value: source.exportProgress)
                            .frame(width: 160)
                        Text("\(Int(source.exportProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let exportedURL = source.exportedVideoURL {
                        Label("Video ready", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)

                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([exportedURL])
                        } label: {
                            Text("Show in Finder")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else if let error = source.exportErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()
                }
                .padding(.leading, 4)
            }
        }
    }

    private func syncButton(for source: CameraSource) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button {
                syncingCameraID = source.id
            } label: {
                Label(source.isSynced ? "Re-sync…" : "Sync…", systemImage: "align.horizontal.left.fill")
            }
            .buttonStyle(.bordered)
            .disabled(garminSource == nil)

            Text(syncStatusText(for: source))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func syncStatusText(for source: CameraSource) -> String {
        guard source.isSynced else { return "Not synced yet" }

        if source.syncOffset == 0 {
            return "In sync (0.0s offset)"
        } else if source.syncOffset > 0 {
            return String(format: "Starts %.1fs after Garmin", source.syncOffset)
        } else {
            return String(format: "Starts %.1fs before Garmin", -source.syncOffset)
        }
    }

    private func sourceCard(name: String, duration: TimeInterval?, thumbnail: NSImage?, trailing: AnyView) -> some View {

        HStack(spacing: 12) {

            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "video")
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(width: 96, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if let duration {
                    Text(durationText(duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Loading…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            trailing
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(nsColor: .separatorColor)))
    }

    private var footer: some View {
        HStack {

            Text("PiP export only for now — layouts and overlays aren't built yet.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                importCameraFootage()
            } label: {
                Label("Import Camera Footage…", systemImage: "video.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    // MARK: - Sheet binding helper

    private var syncingCameraBinding: Binding<CameraSource?> {
        Binding(
            get: {
                guard let id = syncingCameraID else { return nil }
                return cameraSources.first(where: { $0.id == id })
            },
            set: { newValue in
                syncingCameraID = newValue?.id
            }
        )
    }

    private func updateSyncOffset(for cameraID: UUID, offset: TimeInterval) {
        guard let i = cameraSources.firstIndex(where: { $0.id == cameraID }) else { return }
        cameraSources[i].syncOffset = offset
        cameraSources[i].isSynced = true
        // A fresh sync invalidates any previous export of this clip.
        cameraSources[i].exportedVideoURL = nil
        cameraSources[i].exportErrorMessage = nil
        print("🔗 Creator Mode: synced \(cameraSources[i].displayName) at offset \(offset)s")
    }

    // MARK: - Export

    private func exportPiP(for source: CameraSource) {

        guard let garminSource else { return }
        guard let i = cameraSources.firstIndex(where: { $0.id == source.id }) else { return }

        cameraSources[i].isExporting = true
        cameraSources[i].exportProgress = 0
        cameraSources[i].exportedVideoURL = nil
        cameraSources[i].exportErrorMessage = nil

        print("🎬 Creator Mode: starting PiP export for \(source.displayName)")

        PiPExporter.export(
            garminURL: garminSource.url,
            cameraURL: source.url,
            syncOffset: source.syncOffset,
            progress: { value in
                guard let i = cameraSources.firstIndex(where: { $0.id == source.id }) else { return }
                cameraSources[i].exportProgress = value
            },
            completion: { result in
                guard let i = cameraSources.firstIndex(where: { $0.id == source.id }) else { return }
                cameraSources[i].isExporting = false

                switch result {
                case .success(let url):
                    print("✅ Creator Mode: PiP export finished at \(url.path)")
                    cameraSources[i].exportedVideoURL = url
                case .failure(let error):
                    print("❌ Creator Mode: PiP export failed: \(error.localizedDescription)")
                    cameraSources[i].exportErrorMessage = error.localizedDescription
                }
            }
        )
    }

    // MARK: - Garmin source loading

    private func refreshGarminSourceFromFreshConversion() {
        guard let video = mtp.outputVideo, garminSource?.url != video else { return }
        print("🎬 Creator Mode: loading Garmin source from fresh conversion: \(video.path)")
        loadGarminSource(from: video)
    }

    private func importGarminRecording() {

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Select Garmin Recording"
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Movies/Garmin Screen Studio/Videos")

        guard panel.runModal() == .OK, let url = panel.url else {
            print("🎬 Creator Mode: Garmin video selection cancelled")
            return
        }

        print("🎬 Creator Mode: manually selected Garmin video \(url.path)")
        loadGarminSource(from: url)
    }

    private func loadGarminSource(from url: URL) {

        let source = GarminRecordingSource(url: url, thumbnail: nil)
        garminSource = source

        MediaSourceLoader.loadDuration(for: url) { duration in
            print("🎬 Creator Mode: Garmin duration loaded: \(duration ?? -1)")
            guard garminSource?.url == url else { return }
            garminSource?.duration = duration
        }

        MediaSourceLoader.loadThumbnail(for: url) { thumbnail in
            print("🎬 Creator Mode: Garmin thumbnail loaded: \(thumbnail != nil)")
            guard garminSource?.url == url else { return }
            garminSource?.thumbnail = thumbnail
        }
    }

    // MARK: - Camera import

    private func importCameraFootage() {

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import Camera Footage"

        guard panel.runModal() == .OK, let url = panel.url else {
            print("🎥 Creator Mode: camera import cancelled or no URL")
            return
        }

        print("🎥 Creator Mode: importing camera file \(url.path)")

        let source = CameraSource(url: url)
        let sourceID = source.id
        cameraSources.append(source)

        MediaSourceLoader.loadDuration(for: url) { duration in
            print("🎥 Creator Mode: camera duration loaded: \(duration ?? -1)")
            guard let i = cameraSources.firstIndex(where: { $0.id == sourceID }) else { return }
            cameraSources[i].duration = duration
        }

        MediaSourceLoader.loadThumbnail(for: url) { thumbnail in
            print("🎥 Creator Mode: camera thumbnail loaded: \(thumbnail != nil)")
            guard let i = cameraSources.firstIndex(where: { $0.id == sourceID }) else { return }
            cameraSources[i].thumbnail = thumbnail
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
