import SwiftUI

struct BetaActivationView: View {

    @ObservedObject var betaAccess: BetaAccessManager

    @State private var accessCode = ""
    @State private var errorMessage: String?
    @State private var isActivating = false
    @FocusState private var codeFieldFocused: Bool

    private let validator = BetaCodeValidator()

    private var trimmedCode: String {
        accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.panelBackground
                .ignoresSafeArea()

            VStack(spacing: 28) {
                brandHeader

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(betaAccess.isExpired ? "Beta Access Expired" : "Activate Beta Access")
                            .font(.system(size: 28, weight: .bold))

                        Text(betaAccess.isExpired ? expiredMessage : betaMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("BETA ACCESS CODE")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)

                        TextField("Enter beta access code", text: $accessCode)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .focused($codeFieldFocused)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.sidebarBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(errorMessage == nil ? Color.cardBorder : Color.red.opacity(0.7))
                            )
                            .disabled(isActivating)
                            .onSubmit(activateBeta)
                    }

                    if let errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.95))
                        }
                    }

                    Button(action: activateBeta) {
                        HStack(spacing: 8) {
                            if isActivating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                            }

                            Text(isActivating ? "Activating…" : "Activate Beta")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.large)
                    .disabled(trimmedCode.isEmpty || isActivating)

                    Text("Your beta access lasts 90 days from activation and is tied to this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(28)
                .frame(width: 460)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.cardBorder)
                )
            }
        }
        .onAppear {
            codeFieldFocused = true
        }
    }

    private var brandHeader: some View {
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
                Text("Beta")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var betaMessage: String {
        "Thanks for helping test Garmin Screen Studio. Enter your beta access code below to get started."
    }

    private var expiredMessage: String {
        "Your 90-day beta access has ended. Please contact us if you've been invited to continue testing."
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
