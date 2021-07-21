import Foundation

enum BeamObjectManagerError: Error {
    case notSuccess
    case notAuthenticated
    case multipleErrors([Error])
    case beamObjectInvalidChecksum(BeamObject)
    case beamObjectDecodingError
    case beamObjectEncodingError
}

extension BeamObjectManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notSuccess:
            return "Not Success"
        case .notAuthenticated:
            return "Not Authenticated"
        case .multipleErrors(let errors):
            return "Multiple errors: \(errors)"
        case .beamObjectInvalidChecksum(let object):
            return "Invalid Checksum \(object.id)"
        case .beamObjectDecodingError:
            return "Decoding Error"
        case .beamObjectEncodingError:
            return "Encoding Error"
        }
    }
}

enum BeamObjectManagerObjectError<T: BeamObjectProtocol>: Error {
    case beamObjectInvalidChecksum(T)
}

extension BeamObjectManagerObjectError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .beamObjectInvalidChecksum(let object):
            return "Invalid Checksum \(object.beamObjectId)"
        }
    }
}
