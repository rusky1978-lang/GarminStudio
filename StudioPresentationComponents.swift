import SwiftUI

struct StudioCard<Content: View>: View {
    let title: String
    let symbol: String
    var prominence: Prominence = .standard
    @ViewBuilder var content: Content

    enum Prominence {
        case standard
        case soft
    }

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
                .fill(prominence == .soft ? Color.softCardBackground : Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.cardBorder)
        )
    }
}

struct StudioStatusBadge: View {
    enum Style {
        case healthy
        case working
        case warning
        case failure
        case neutral

        var color: Color {
            switch self {
            case .healthy: .green
            case .working: .blue
            case .warning: .orange
            case .failure: .red
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

struct StudioMetricRow: View {
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

struct SystemHealthRow: View {
    enum State {
        case healthy
        case warning
        case failure
        case neutral

        var symbol: String {
            switch self {
            case .healthy: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .failure: "xmark.circle.fill"
            case .neutral: "circle"
            }
        }

        var tint: Color {
            switch self {
            case .healthy: .green
            case .warning: .orange
            case .failure: .red
            case .neutral: Color(nsColor: .secondaryLabelColor)
            }
        }
    }

    let title: String
    let detail: String
    let state: State

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(state.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct PhasePageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
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

            trailing
        }
    }
}

extension PhasePageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String, symbol: String) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        trailing = EmptyView()
    }
}
