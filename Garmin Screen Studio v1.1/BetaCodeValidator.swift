import Foundation

struct BetaCodeValidator {

    enum ValidationResult: Equatable {
        case valid(activatedAt: Date?)
        case alreadyActivated
        case invalid
        case revoked
    }

    enum ValidationError: LocalizedError, Equatable {
        case invalidCode
        case alreadyActivated
        case revokedCode
        case serverError
        case networkFailure
        case malformedResponse
        case unexpectedHTTPResponse
        case timeout

        var errorDescription: String? {
            switch self {
            case .invalidCode:
                return "That beta access code isn't valid. Please check the code and try again."
            case .alreadyActivated:
                return "That beta access code has already been activated. Please contact us if you need help."
            case .revokedCode:
                return "This beta access code has been revoked. Please contact us if you think this is a mistake."
            case .serverError:
                return "The activation server couldn't process your request. Please try again later."
            case .networkFailure:
                return "Unable to contact the activation server. Please check your internet connection and try again."
            case .malformedResponse:
                return "The activation server returned an unexpected response. Please try again later."
            case .unexpectedHTTPResponse:
                return "The activation server returned an unexpected response. Please try again later."
            case .timeout:
                return "The activation request timed out. Please check your internet connection and try again."
            }
        }
    }

    private struct ValidationRequest: Encodable {
        let code: String
    }

    struct BetaActivationResponse: Decodable, Equatable {
        let status: Status
        let activatedAt: Date?
    }

    enum Status: String, Decodable, Equatable {
        case valid
        case alreadyActivated = "already_activated"
        case invalid
        case revoked
        case error
    }

    private let endpoint = URL(string: "https://script.google.com/macros/s/AKfycbz5HVFfeNp-BYnBiu8anxbMR4aude9Se503G_lADvqQXvcoH9PvKiZcS-uZfDfM6L5c3g/exec")!
    private let timeoutInterval: TimeInterval = 15

    func validate(code: String) async throws -> ValidationResult {
        let cleanedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedCode.isEmpty else {
            throw ValidationError.invalidCode
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(ValidationRequest(code: cleanedCode))

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ValidationError.timeout
        } catch {
            throw ValidationError.networkFailure
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ValidationError.unexpectedHTTPResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ValidationError.unexpectedHTTPResponse
        }

        let activationResponse: BetaActivationResponse

        do {
            activationResponse = try Self.decoder.decode(BetaActivationResponse.self, from: data)
        } catch {
            throw ValidationError.malformedResponse
        }

        switch activationResponse.status {
        case .valid:
            return .valid(activatedAt: activationResponse.activatedAt)
        case .alreadyActivated:
            throw ValidationError.alreadyActivated
        case .invalid:
            throw ValidationError.invalidCode
        case .revoked:
            throw ValidationError.revokedCode
        case .error:
            throw ValidationError.serverError
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = fractionalFormatter.date(from: dateString) {
                return date
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]

            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO 8601 date."
            )
        }
        return decoder
    }()
}
