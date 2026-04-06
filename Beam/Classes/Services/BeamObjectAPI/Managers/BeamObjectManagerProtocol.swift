import Foundation
import BeamCore

protocol BeamObjectManagerDelegateProtocol {
    static var conflictPolicy: BeamObjectConflictResolution { get }
    func parse<T: BeamObjectProtocol>(objects: [T]) throws
    func saveAllOnBeamObjectApi(force: Bool, progress: ((Float) -> Void)?) async throws -> (Int, Date?)
    func saveChangedObjects() async throws
    func isChangedObjectsEmpty() -> Bool
}

protocol BeamObjectManagerDelegate: AnyObject, BeamObjectManagerDelegateProtocol {
    associatedtype BeamObjectType: BeamObjectProtocol
    static var uploadType: BeamObjectRequestUploadType { get }

    var objectManager: BeamObjectManager { get }
    var changedObjects: [UUID: BeamObjectType] { get set }

    func registerOnBeamObjectManager(_ objectManager: BeamObjectManager)
    func receivedObjects(_ objects: [BeamObjectType]) throws
    func allObjects(updatedSince: Date?) throws -> [BeamObjectType]
    func willSaveAllOnBeamObjectApi()
    func manageConflict(_ object: BeamObjectType, _ remoteObject: BeamObjectType) throws -> BeamObjectType
    func saveObjectsAfterConflict(_ objects: [BeamObjectType]) throws
}

enum BeamObjectManagerDelegateError: Error {
    case runtimeError(String)
    case nestedTooDeep
}

extension BeamObjectManagerDelegateError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .runtimeError(let text): return text
        case .nestedTooDeep: return "Nested too deep"
        }
    }
}

// Default implementations — sync removed, all no-ops
extension BeamObjectManagerDelegate {
    static var uploadType: BeamObjectRequestUploadType { .multipartUpload }
    static var conflictPolicy: BeamObjectConflictResolution { .replace }

    func registerOnBeamObjectManager(_ objectManager: BeamObjectManager) {
        objectManager.register(self, object: BeamObjectType.self)
    }

    func parse<T: BeamObjectProtocol>(objects: [T]) throws {
        guard let parsedObjects = objects as? [BeamObjectType] else { return }
        try receivedObjects(parsedObjects)
    }

    func saveAllOnBeamObjectApi(force: Bool, progress: ((Float) -> Void)?) async throws -> (Int, Date?) {
        return (0, nil)
    }

    func saveChangedObjects() async throws {}
    func isChangedObjectsEmpty() -> Bool { true }
    func willSaveAllOnBeamObjectApi() {}
    func manageConflict(_ object: BeamObjectType, _ remoteObject: BeamObjectType) throws -> BeamObjectType { object }
    func saveObjectsAfterConflict(_ objects: [BeamObjectType]) throws {}

    // Stub replacements for removed sync methods
    func saveOnBeamObjectAPI(_ object: BeamObjectType) async throws {}
    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType]) async throws {}
    func deleteAllFromBeamObjectAPI() async throws {}
}
