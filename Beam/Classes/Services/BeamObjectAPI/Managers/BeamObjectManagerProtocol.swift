import Foundation
import BeamCore

protocol BeamObjectManagerDelegateProtocol {
    static var conflictPolicy: BeamObjectConflictResolution { get }

    func parse<T: BeamObjectProtocol>(objects: [T]) throws

    // Called when `BeamObjectManager` wants to store all existing `Document` as `BeamObject`
    // it will call this method
    func saveAllOnBeamObjectApi(force: Bool, _ completion: @escaping ((Swift.Result<(Int, Date?), Error>) -> Void)) throws -> APIRequest?

    func saveAllOnBeamObjectApi(force: Bool) async throws -> (Int, Date?)
}

protocol BeamObjectManagerDelegate: AnyObject, BeamObjectManagerDelegateProtocol {
    associatedtype BeamObjectType: BeamObjectProtocol
    static var uploadType: BeamObjectRequestUploadType { get }
    static var backgroundQueue: DispatchQueue { get }
    func registerOnBeamObjectManager()

    /// When new objects have been received and should be stored locally by the manager
    func receivedObjects(_ objects: [BeamObjectType]) throws

    /// Returns all objects, used to save all of them as beam objects
    func allObjects(updatedSince: Date?) throws -> [BeamObjectType]

    /// Will be called before savingAll objects
    func willSaveAllOnBeamObjectApi()

    /// When doing manual conflict management. `object` and `remoteObject` can be the same if the conflict was only
    /// because of a checksum issue, when we locally have stored previousChecksum but it's been deleted on the server
    /// side
    /// You only need to use this when you have manual conflict management, see `DocumentManager` for an example of how to implement it, and
    /// `DatabaseManager` if you don't handle conflict manually
    func manageConflict(_ object: BeamObjectType,
                        _ remoteObject: BeamObjectType) throws -> BeamObjectType

    /// When a conflict happens, we will resend a potentially updated version and should store its result without trying to merge in a smart way
    func saveObjectsAfterConflict(_ objects: [BeamObjectType]) throws
}

enum BeamObjectManagerDelegateError: Error {
    case runtimeError(String)
    case nestedTooDeep
}

extension BeamObjectManagerDelegateError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .runtimeError(let text):
            return text
        case .nestedTooDeep:
            return "Nested too deep"
        }
    }
}

extension BeamObjectManagerDelegate {
    static var uploadType: BeamObjectRequestUploadType {
        // Note: we want to be able to "force" a certain type during tests
        #if DEBUG
        if EnvironmentVariables.env == "test" {
            return BeamObjectManager.uploadTypeForTests
        }
        #endif

        return .multipartUpload
    }

    func registerOnBeamObjectManager() {
        BeamObjectManager.register(self, object: BeamObjectType.self)
    }

    func parse<T: BeamObjectProtocol>(objects: [T]) throws {
        guard let parsedObjects = objects as? [BeamObjectType] else {
            return
        }

        var objectIds = objects.map { $0.beamObjectId.uuidString.lowercased() }
        if objectIds.count > 3 {
            objectIds = Array(objectIds[0...3])
            objectIds.append("...")
        }

        Logger.shared.logDebug("Received \(parsedObjects.count) \(T.beamObjectType): \(objectIds)",
                               category: .beamObjectNetwork)
        Logger.shared.logDebug("Calling manager for \(T.beamObjectType)", category: .beamObjectNetwork)

        try receivedObjects(parsedObjects)
    }
}
