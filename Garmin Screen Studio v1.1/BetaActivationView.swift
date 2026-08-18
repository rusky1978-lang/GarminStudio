import SwiftUI

struct BetaActivationView: View {

    @ObservedObject var betaAccess: BetaAccessManager

    @State private var accessCode = ""
    @State private var errorMessage: String?
    @State private var isActivating = false
    @FocusState private var codeFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let validator = BetaCodeValidator()

    private var trimmedCode: String {
        accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.panelBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                activationCard
                supportingBadges
            }
            .padding(40)
        }
        .onAppear {
            codeFieldFocused = true
        }
    }

    private var activationCard: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                AppIdentityMark(size: 78)
                    .shadow(color: Color.black.opacity(0.16), radius: 16, y: 8)

                VStack(spacing: 4) {
                    Text("Garmin Screen Studio")
                        .font(.system(size: 28, weight: .bold))
                    Text("Beta Access")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 18) {
                Text(betaAccess.isExpired ? expiredMessage : betaMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Beta Key")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("Enter beta access key", text: $accessCode)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .focused($codeFieldFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.elevatedCardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(errorMessage == nil ? Color.cardBorder : Color.red.opacity(0.7), lineWidth: errorMessage == nil ? 1 : 1.4)
                        )
                        .disabled(isActivating)
                        .onSubmit(activateBeta)
                        .accessibilityLabel("Beta access key")
                }

                statusMessage

                Button(action: activateBeta) {
                    HStack(spacing: 8) {
                        if isActivating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                        }

                        Text(isActivating ? "Activating…" : "Activate")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)
                .disabled(trimmedCode.isEmpty || isActivating)
            }
        }
        .padding(30)
        .frame(width: 470)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.cardBorder)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 22, y: 12)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isActivating)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: errorMessage)
    }

    @ViewBuilder
    private var statusMessage: some View {
        if isActivating {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.blue)
                Text("Validating your beta access…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)
        } else if let errorMessage {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .transition(.opacity)
        }
    }

    private var supportingBadges: some View {
        HStack(spacing: 12) {
            Label("90-day beta access", systemImage: "calendar")
            Label("Secure online validation", systemImage: "lock.shield")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private var betaMessage: String {
        "Enter the beta access key you received to activate this Mac."
    }

    private var expiredMessage: String {
        "Your 90-day beta access has ended. Enter a new beta access key if you have been invited to continue testing."
    }

    private func activateBeta() {
        guard !trimmedCode.isEmpty, !isActivating else {
            return
        }

        isActivating = true
        errorMessage = nil

        Task {
            do {
                let result = try await validator.validate(code: trimmedCode)

                await MainActor.run {
                    isActivating = false

                    switch result {
                    case .valid:
                        if betaAccess.activateValidatedBeta() {
                            errorMessage = nil
                        } else {
                            errorMessage = "This beta access period has expired."
                        }
                    case .alreadyActivated:
                        errorMessage = BetaCodeValidator.ValidationError.alreadyActivated.localizedDescription
                    case .invalid:
                        errorMessage = BetaCodeValidator.ValidationError.invalidCode.localizedDescription
                    case .revoked:
                        errorMessage = BetaCodeValidator.ValidationError.revokedCode.localizedDescription
                    }
                }
            } catch let validationError as BetaCodeValidator.ValidationError {
                await MainActor.run {
                    isActivating = false
                    errorMessage = validationError.localizedDescription
                }
            } catch {
                await MainActor.run {
                    isActivating = false
                    errorMessage = BetaCodeValidator.ValidationError.networkFailure.localizedDescription
                }
            }
        }
    }
}

#Preview {
    BetaActivationView(betaAccess: BetaAccessManager())
}
