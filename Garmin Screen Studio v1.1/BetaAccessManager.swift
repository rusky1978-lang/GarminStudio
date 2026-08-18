import Foundation
import Combine

final class BetaAccessManager: ObservableObject {

    // MARK: - Beta Configuration

    /// Length of the beta access period.
    private let betaDuration: TimeInterval = 90 * 24 * 60 * 60

    // MARK: - Stored State

    @Published private(set) var isActivated: Bool = false
    @Published private(set) var activationDate: Date?
    @Published private(set) var expiryDate: Date?

    private let activationDateKey = "BetaAccess.activationDate"

    // MARK: - Initialisation

    init() {
        loadActivation()
    }

    // MARK: - Public Properties

    var daysRemaining: Int {
        guard let expiryDate else {
            return 0
        }

        let remaining = Calendar.current.dateComponents(
            [.day],
            from: Date(),
            to: expiryDate
        ).day ?? 0

        return max(0, remaining)
    }

    var isExpired: Bool {
        guard let expiryDate else {
            return false
        }

        return Date() >= expiryDate
    }

    var hasValidAccess: Bool {
        isActivated && !isExpired
    }

    // MARK: - Activation

    @discardableResult
    func activateValidatedBeta() -> Bool {
        // Don't reset the user's 90 days if activation is attempted again.
        if isActivated {
            return !isExpired
        }

        let now = Date()
        let expiry = now.addingTimeInterval(betaDuration)

        activationDate = now
        expiryDate = expiry
        isActivated = true

        UserDefaults.standard.set(now, forKey: activationDateKey)

        return true
    }

    // MARK: - Persistence

    private func loadActivation() {
        guard let savedDate = UserDefaults.standard.object(
            forKey: activationDateKey
        ) as? Date else {
            return
        }

        activationDate = savedDate
        expiryDate = savedDate.addingTimeInterval(betaDuration)
        isActivated = true
    }
}
