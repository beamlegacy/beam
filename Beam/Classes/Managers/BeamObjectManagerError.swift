import Foundation

enum BeamObjectManagerError: Error {
    case notSuccess
    case notAuthenticated
    case multipleErrors([Error])
    case invalidChecksum(BeamObject)
    case decodingError(BeamObject)
    case encodingError
    case invalidObjectType(BeamObject, BeamObject)
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
        case .invalidChecksum(let object):
            return "Invalid Checksum \(object.id)"
        case .decodingError(let object):
            return "Decoding Error \(object)"
        case .encodingError:
            return "Encoding Error"
        case .invalidObjectType(let localObject, let remoteObject):
            return "invalidObjectType local: \(localObject) remote: \(remoteObject)"
        }
    }
}

enum BeamObjectManagerObjectError<T: BeamObjectProtocol>: Error {
    case invalidChecksum(T)
}

extension BeamObjectManagerObjectError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidChecksum(let object):
            return "Invalid Checksum \(object.beamObjectId)"
        }
    }
}
