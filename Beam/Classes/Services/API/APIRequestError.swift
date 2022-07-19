import Foundation
import BeamCore

enum APIRequestError: Error {
    case forbidden
    case unauthorized
    case internalServerError
    case notFound
    case error
    case parserError
    case deviceNotFound
    case notAuthenticated
    case beamObjectInvalidChecksum(Errorable)
    case apiError([String])
    case apiErrors(Errorable)
    case apiRequestErrors([APIRequest.ErrorData])
    case operationCancelled
    case duplicateTitle
    case syncDisabledByFeatureFlag
}

extension APIRequestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .beamObjectInvalidChecksum:
            return loc("error.api.beamObject.invalidChecksum")
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
        case .apiErrors(let errorable):
            var errorStrings: [String] = errorable.errors?.compactMap {
                if let path = $0.path?.joined(separator: ", "), let message = $0.message {
                    return "\($0.objectid ?? "?"): \(path): \(message)"
                } else {
                    return "\(String(describing: $0.path?.joined(separator: ", "))): \(String(describing: $0.message))"
                }
            } ?? []

            if errorStrings.count > 10 {
                errorStrings = Array(errorStrings[0...10])
                errorStrings.append("...")
            }

            errorStrings.insert("\(errorable.errors?.count ?? 0) errors", at: 0)

            return errorStrings.joined(separator: "; ")
        case .notFound:
            return loc("error.api.notFound")
        case .error:
            return loc("error.api.Error")
        case .operationCancelled:
            return loc("error.api.operationCancelled")
        case .apiRequestErrors(let errors):
            return errors.compactMap {
                $0.message
            }.joined(separator: ", ")
        case .syncDisabledByFeatureFlag:
            return loc("error.api.syncDisabledByFeatureFlag")
        }
    }
}
