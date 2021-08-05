import Foundation

enum BeamObjectManagerError: Error {
    case notAuthenticated
    case multipleErrors([Error])
    case invalidChecksum(BeamObject)
    case decodingError(BeamObject)
    case encodingError
    case invalidObjectType(BeamObject, BeamObject)
    case beamObjectAPIDisabled
}

extension BeamObjectManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
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
        case .beamObjectAPIDisabled:
            return "BeamObject API is disabled"
        case .invalidObjectType(let localObject, let remoteObject):
            return "invalidObjectType local: \(localObject) remote: \(remoteObject)"
        }
    }
}

enum BeamObjectManagerObjectError<T: BeamObjectProtocol>: Error {
    case invalidChecksum([T], [T], [T])
}

extension BeamObjectManagerObjectError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidChecksum(let conflictedObjects, let goodObjects, let remoteObjects):
            return "Invalid Checksums: \(conflictedObjects.map { $0.beamObjectId }), good objects: \(goodObjects.map { $0.beamObjectId }), remote objects: \(remoteObjects.map { $0.beamObjectId })"
        }
    }
}
