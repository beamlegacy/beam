import Foundation

protocol BeamObjectManagerDelegateProtocol {
    func parse<T: BeamObjectProtocol>(objects: [T]) throws

    // Called when `BeamObjectManager` wants to store all existing `Document` as `BeamObject`
    // it will call this method
    func saveAllOnBeamObjectApi(_ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?
}

protocol BeamObjectManagerDelegate: class, BeamObjectManagerDelegateProtocol {
    associatedtype BeamObjectType: BeamObjectProtocol
    func registerOnBeamObjectManager()

    // When new objects have been received and should be stored locally by the manager
    func receivedObjects(_ objects: [BeamObjectType]) throws

    // Called within `DocumentManager` to store this object as `BeamObject`
    func saveOnBeamObjectAPI(_ object: BeamObjectType,
                             _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?
    // Called within `DocumentManager` to store those objects as `BeamObject`
    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType],
                              _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?
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
}
