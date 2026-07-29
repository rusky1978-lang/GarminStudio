import SwiftUI

struct RecordingBrowserView: View {

    @ObservedObject var mtp: MTPManager
    @Environment(\.dismiss) private var dismiss

    @State private var selection = Set<UInt32>()

    var body: some View {

        VStack(spacing: 0) {

            header

            Divider()

            content

            Divider()

            footer
        }
        .frame(width: 640, height: 460)
        .onAppear {
            if mtp.recordings.isEmpty {
                mtp.scanRecordings()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Recordings on \(mtp.deviceConnected ? mtp.deviceName : "Garmin")")
                .font(.headline)

            Spacer()

            Button {
                mtp.scanRecordings()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(mtp.isScanningRecordings)
            .help("Refresh")

            Button("Done") { dismiss() }
        }
        .padding(16)
    }

    private var content: some View {
        Group {
            if mtp.isScanningRecordings {

                VStack(spacing: 10) {
                    ProgressView()
                    Text(mtp.scanStatus.isEmpty ? "Scanning…" : mtp.scanStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if mtp.recordings.isEmpty {

                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No recordings found")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {

                Table(mtp.recordings, selection: $selection) {
                    TableColumn("Name") { recording in
                        Text(recording.name)
                    }
                    TableColumn("Date") { recording in
                        Text(recording.dateText)
                    }
                    TableColumn("Frames") { recording in
                        Text("\(recording.imageCount)")
                    }
                    TableColumn("Est. Duration") { recording in
                        Text(recording.durationText)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {

            Text(selection.isEmpty ? "No recording selected" : "\(selection.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive) {
                deleteSelected()
            } label: {
                Label("Delete Selected", systemImage: "trash")
            }
            .disabled(selection.isEmpty)

            Button {
                importSelected()
            } label: {
                Label("Import Selected", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selection.count != 1)
        }
        .padding(16)
    }

    private func importSelected() {
        guard let id = selection.first,
              let recording = mtp.recordings.first(where: { $0.id == id }) else { return }
        mtp.importRecording(recording)
        dismiss()
    }

    private func deleteSelected() {
        let toDelete = mtp.recordings.filter { selection.contains($0.id) }
        mtp.deleteRecordings(toDelete)
        selection.removeAll()
    }
}
