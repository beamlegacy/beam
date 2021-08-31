import Foundation
import BeamCore

protocol BeamObjectManagerDelegateProtocol {
    static var conflictPolicy: BeamObjectConflictResolution { get }

    func parse<T: BeamObjectProtocol>(objects: [T]) throws

    // Called when `BeamObjectManager` wants to store all existing `Document` as `BeamObject`
    // it will call this method
    func saveAllOnBeamObjectApi(_ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> APIRequest?
}

protocol BeamObjectManagerDelegate: AnyObject, BeamObjectManagerDelegateProtocol {
    associatedtype BeamObjectType: BeamObjectProtocol
    func registerOnBeamObjectManager()

    /// When new objects have been received and should be stored locally by the manager
    func receivedObjects(_ objects: [BeamObjectType]) throws

    /// Needed to store checksum and resend them in a future network request
    func persistChecksum(_ objects: [BeamObjectType]) throws

    /// Returns all objects, used to save all of them as beam objects
    func allObjects() throws -> [BeamObjectType]

    /// Will be called before savingAll objects
    func willSaveAllOnBeamObjectApi()

    /// When doing manual conflict management. `object` and `remoteObject` can be the same if the conflict was only
    /// because of a checksum issue, when we locally have stored previousChecksum but it's been deleted on the server
    /// side
    func manageConflict(_ object: BeamObjectType,
                        _ remoteObject: BeamObjectType) throws -> BeamObjectType

    /// When a conflict happens, we will resend a potentially updated version and should store its result
    func saveObjectsAfterConflict(_ objects: [BeamObjectType]) throws
}

enum BeamObjectManagerDelegateError: Error {
    case runtimeError(String)
}

extension BeamObjectManagerDelegateError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .runtimeError(let text):
            return text
        }
    }
}

extension BeamObjectManagerDelegate {
    func registerOnBeamObjectManager() {
        BeamObjectManager.register(self, object: BeamObjectType.self)
    }

    func parse<T: BeamObjectProtocol>(objects: [T]) throws {
        guard let parsedObjects = objects as? [BeamObjectType] else {
            return
        }

        try receivedObjects(parsedObjects)
    }

    func manageConflict(_ object: BeamObjectType,
                        _ remoteObject: BeamObjectType) throws -> BeamObjectType {
        fatalError("manageConflict must be implemented by \(BeamObjectType.beamObjectTypeName) manager")
    }

    func saveObjectsAfterConflict(_ objects: [BeamObjectType]) throws {
        fatalError("saveObjectsAfterConflict must be implemented by \(BeamObjectType.beamObjectTypeName) manager")
    }

    func updatedObjectsOnly(_ objects: [BeamObjectType]) -> [BeamObjectType] {
        objects.filter {
            $0.previousChecksum != $0.checksum || $0.previousChecksum == nil
        }
    }

    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType]) throws {
        guard !objects.isEmpty else { return }

        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        try self.saveOnBeamObjectsAPI(objects) { result in
            switch result {
            case .failure(let returnedError):
                Logger.shared.logError("Can't save: \(returnedError.localizedDescription)", category: .beamObjectNetwork)
                error = returnedError
            case .success:
                Logger.shared.logDebug("Saved \(objects.count) objects", category: .beamObjectNetwork)
            }
            semaphore.signal()
        }

        let semaphoreResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(30))
        if case .timedOut = semaphoreResult {
            Logger.shared.logError("Semaphore timedout", category: .beamObjectNetwork)
        }

        if let error = error { throw error }
    }
}
