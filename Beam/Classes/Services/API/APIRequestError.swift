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
    case operationCancelled
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
        case .notFound:
            return loc("error.api.notFound")
        case .error:
            return loc("error.api.Error")
        case .operationCancelled:
            return loc("error.api.operationCancelled")
        }
    }
}
