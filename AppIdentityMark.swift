import SwiftUI
import AppKit

struct AppIdentityMark: View {
    var size: CGFloat = 48
    var showsFallbackSymbol = true

    var body: some View {
        ZStack {
            if let image = NSApp.applicationIconImage, image.isValid, image.size != .zero {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            } else {
                fallbackMark
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Garmin Screen Studio")
    }

    private var fallbackMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .labelColor).opacity(0.9),
                            Color(nsColor: .labelColor).opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.88), lineWidth: max(1, size * 0.035))
                .frame(width: size * 0.48, height: size * 0.36)

            if showsFallbackSymbol {
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: size * 0.28, weight: .semibold))
                    .foregroundStyle(Color.blue)
            }

            Circle()
                .fill(Color.blue)
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(x: size * 0.24, y: -size * 0.24)
        }
    }
}
