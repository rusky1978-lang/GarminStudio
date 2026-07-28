import SwiftUI
import AVKit
import AVFoundation

/// Milestone 2 of Creator Mode: manual synchronisation.
///
/// Deliberately has ONE editable offset value (`offset`), regardless of
/// whether it was set by marking matching moments in both clips or by
/// hand-nudging afterward — per the design doc's rule that automatic and
/// manual sync must always share a single source of truth, never two
/// separate fields that could diverge.
struct SyncView: View {

    let garminURL: URL
    let cameraURL: URL

    /// Starting offset if one was already set previously for this pair.
    var initialOffset: TimeInterval

    var onSave: (TimeInterval) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var garminPlayer: AVPlayer
    @State private var cameraPlayer: AVPlayer

    @State private var garminMarkSeconds: Double?
    @State private var cameraMarkSeconds: Double?

    @State private var offset: TimeInterval

    init(garminURL: URL, cameraURL: URL, initialOffset: TimeInterval, onSave: @escaping (TimeInterval) -> Void) {
        self.garminURL = garminURL
        self.cameraURL = cameraURL
        self.initialOffset = initialOffset
        self.onSave = onSave
        _garminPlayer = State(initialValue: AVPlayer(url: garminURL))
        _cameraPlayer = State(initialValue: AVPlayer(url: cameraURL))
        _offset = State(initialValue: initialOffset)
    }

    var body: some View {

        VStack(spacing: 0) {

            header

            Divider()

            HStack(spacing: 16) {
                clipColumn(title: "Garmin Recording", player: garminPlayer) {
                    garminMarkSeconds = currentSeconds(of: garminPlayer)
                    recalculateOffsetIfPossible()
                }

                clipColumn(title: "Camera Footage", player: cameraPlayer) {
                    cameraMarkSeconds = currentSeconds(of: cameraPlayer)
                    recalculateOffsetIfPossible()
                }
            }
            .padding(16)

            Divider()

            offsetControl

            Divider()

            footer
        }
        .frame(width: 780, height: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Sync Camera Footage")
                .font(.headline)
            Text("Scrub each clip to the same moment (e.g. a bump, a turn, a shout) and mark it in both.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func clipColumn(title: String, player: AVPlayer, onMark: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            VideoPlayer(player: player)
                .frame(height: 220)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                onMark()
            } label: {
                Label("Mark This Moment", systemImage: "flag.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }

    private var offsetControl: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("Sync Offset")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if let g = garminMarkSeconds, let c = cameraMarkSeconds {
                    Text("Marked: Garmin \(timeText(g)) ↔ Camera \(timeText(c))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {

                Text("Camera starts")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper(
                    value: $offset,
                    in: -3600...3600,
                    step: 0.1
                ) {
                    Text(offsetDescription)
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                }
                .frame(width: 320)

                Spacer()
            }

            Text("This number always stays editable here, whether it was set by marking moments above or by nudging the stepper directly — there's no separate \"automatic\" value hiding behind it.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var offsetDescription: String {
        if offset == 0 {
            return "in sync (0.0s offset)"
        } else if offset > 0 {
            return String(format: "%.1fs AFTER Garmin", offset)
        } else {
            return String(format: "%.1fs BEFORE Garmin", -offset)
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }

            Spacer()

            Button {
                onSave(offset)
                dismiss()
            } label: {
                Text("Save Sync")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    // MARK: - Helpers

    private func currentSeconds(of player: AVPlayer) -> Double {
        CMTimeGetSeconds(player.currentTime())
    }

    private func recalculateOffsetIfPossible() {
        guard let g = garminMarkSeconds, let c = cameraMarkSeconds else { return }
        // If the camera's marked moment is at c seconds into the camera
        // clip, and the SAME real moment is at g seconds into the Garmin
        // clip, then the camera needs to start `g - c` seconds relative
        // to the Garmin clip's start.
        offset = g - c
    }

    private func timeText(_ seconds: Double) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
