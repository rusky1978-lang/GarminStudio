import SwiftUI
import AppKit
import Combine

struct ContentView: View {

    @StateObject private var mtp = MTPManager()
    

    var body: some View {

        VStack(spacing: 24) {

            Image(systemName: "bicycle.circle.fill")
                .font(.system(size: 84))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)

            Text("Garmin Screen Studio")
                .font(.system(size: 34, weight: .bold))
                .tracking(0.5)

            VStack(spacing: 12) {

                Text(mtp.status)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.25), value: mtp.status)

                if mtp.isWorking {

                    ProgressView(value: mtp.progress)
                        .frame(width: 300)
                    
                    Text("\(Int(mtp.progress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                } else if mtp.finished {

                    Image(systemName: "checkmark.circle.fill")
                        .transition(.scale.combined(with: .opacity))
                        .font(.system(size: 36))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.green, .green.opacity(0.3))

                    if let video = mtp.outputVideo {

                        Button("📂 Show Video") {

                            NSWorkspace.shared.activateFileViewerSelecting([video])

                        }

                    }

                }

            }

            Button {

                mtp.test()

            } label: {

                Label(
                    mtp.isWorking ? "Importing..." : "Import Latest Recording",
                    systemImage: mtp.isWorking ? "hourglass" : "arrow.down.circle.fill"
                )

            }
            .disabled(mtp.isWorking)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Divider()

            ScrollView {

                LazyVStack(alignment: .leading, spacing: 4) {

                    ForEach(mtp.activityLog, id: \.self) { message in

                        Text(message)
                            .font(.caption.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)

                    }

                }

            }
            .frame(height: 100)

            Spacer(minLength: 20)

        }
        .padding(28)
        .frame(width: 520, height: 340)
       
        }

    }



#Preview {
    ContentView()
}
