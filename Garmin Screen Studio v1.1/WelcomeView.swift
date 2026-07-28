import SwiftUI

struct WelcomeView: View {

    var onContinue: () -> Void

    var body: some View {

        VStack(spacing: 20) {

            Image(systemName: "bicycle.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .padding(.top, 12)

            Text("Welcome to Garmin Screen Studio Beta")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(spacing: 14) {

                Text("Thank you for testing Garmin Screen Studio.")

                Text("This is an early beta release and your feedback is incredibly valuable.")

                Text("If you discover any bugs or have suggestions, please let me know.")

                Text("Enjoy!")

                VStack(spacing: 2) {
                    Text("Russell Gosling")
                    Text("Cycling with Russ")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)

            Button("Continue") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)

        }
        .padding(32)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
