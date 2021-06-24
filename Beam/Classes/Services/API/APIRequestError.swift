import Foundation
import BeamCore

enum APIRequestError: Error, Equatable {
    case forbidden
    case unauthorized
    case internalServerError
    case notFound
    case error
    case parserError
    case deviceNotFound
    case notAuthenticated
    case documentConflict
    case apiError([String])
    case apiErrors([UserErrorData])
    case operationCancelled
    case duplicateTitle
}

extension APIRequestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .documentConflict:
            return loc("error.api.document.conflict")
        case .parserError:
            return loc("error.api.parserError")
        case .forbidden:
            return loc("error.api.forbidden")
        case .unauthorized:
            return loc("error.api.unauthorized")
        case .deviceNotFound:
            return loc("error.api.deviceNotFound")
        case .internalServerError:
            return loc("error.api.internalServerError")
        case .notAuthenticated:
            return loc("error.api.notAuthenticated")
        case .apiError(let explanations):
            return explanations.joined(separator: ", ")
        case .duplicateTitle:
            return loc("error.api.duplicateTitle")
        case .apiErrors(let errors):
            return errors.compactMap {
                if let path = $0.path?.joined(separator: ", "), let message = $0.message {
                    return "\(path): \(message)"
                } else {
                    return "\(String(describing: $0.path?.joined(separator: ", "))): \(String(describing: $0.message))"
                }
            }.joined(separator: ", ")
        case .notFound:
            return loc("error.api.notFound")
        case .error:
            return loc("error.api.Error")
        case .operationCancelled:
            return loc("error.api.operationCancelled")
        }
    }
}
