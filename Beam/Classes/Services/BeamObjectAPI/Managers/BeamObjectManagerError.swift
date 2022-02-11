import Foundation

enum BeamObjectManagerError: Error {
    case parsingError(String)
    case notAuthenticated
    case multipleErrors([Error])
    case invalidChecksum(BeamObject)
    case decodingError(BeamObject)
    case encodingError
    case invalidObjectType(BeamObject, BeamObject)
    case beamObjectAPIDisabled
    case fetchError
    case saveError
    case nestedTooDeep
    case sendingObjectsDisabled
}

extension BeamObjectManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .parsingError(let message):
            return message
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
        case .fetchError:
            return "Fetching error"
        case .saveError:
            return "Save error"
        case .nestedTooDeep:
            return "Nested too deep"
        case .sendingObjectsDisabled:
            return "Sending objects is disabled until first sync is complete"
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
            var conflictedObjectIds = conflictedObjects.map { $0.beamObjectId.uuidString }
            if conflictedObjectIds.count > 10 {
                conflictedObjectIds = Array(conflictedObjectIds[0...10])
                conflictedObjectIds.append("...")
            }

            var goodObjectsIds = goodObjects.map { $0.beamObjectId.uuidString }
            if goodObjectsIds.count > 10 {
                goodObjectsIds = Array(goodObjectsIds[0...10])
                goodObjectsIds.append("...")
            }

            var remoteObjectsIds = remoteObjects.map { $0.beamObjectId.uuidString }
            if remoteObjectsIds.count > 10 {
                remoteObjectsIds = Array(remoteObjectsIds[0...10])
                remoteObjectsIds.append("...")
            }

            return "Invalid Checksums: \(conflictedObjects.count) \(conflictedObjectIds), \(goodObjects.count) good objects: \(goodObjectsIds), \(remoteObjects.count) remote objects: \(remoteObjectsIds)"
        }
    }
}
