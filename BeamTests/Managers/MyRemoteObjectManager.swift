import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
@testable import BeamCore

// Minimal manager
class MyRemoteObjectManager {
    static var receivedMyRemoteObjects: [MyRemoteObject] = []
    static var store: [UUID: MyRemoteObject] = [:]
}

extension MyRemoteObjectManager: BeamObjectManagerDelegate {
    func willSaveAllOnBeamObjectApi() { }

    static var conflictPolicy: BeamObjectConflictResolution = .replace
    internal static var backgroundQueue: DispatchQueue = DispatchQueue(label: "MyRemoteObjectManager BeamObjectManager backgroundQueue", qos: .userInitiated)

    func receivedObjects(_ objects: [MyRemoteObject]) throws {
        for object in objects {
            /*
             When receiving objects, it's a good pattern to skip if what you received was already in store
             */
            if let localObject = Self.store[object.beamObjectId],
               self.isEqual(localObject, to: object) {
                continue
            }

            Self.store[object.beamObjectId] = object
        }

        Self.receivedMyRemoteObjects.append(contentsOf: objects)
    }

    func allObjects(updatedSince: Date?) throws -> [MyRemoteObject] {
        Array(Self.store.values)
    }

    func manageConflict(_ object: MyRemoteObject,
                        _ remoteObject: MyRemoteObject) throws -> MyRemoteObject {
        var result = object.copy()

        var newTitle = "merged: "

        if let title = object.title {
            newTitle = newTitle + title
        }

        if let title = remoteObject.title {
            newTitle = newTitle + title
        }

        result.title = newTitle
        return result
    }

    func saveObjectsAfterConflict(_ objects: [MyRemoteObject]) throws {
        for object in objects {
            Self.store[object.beamObjectId] = object
            try BeamObjectChecksum.savePreviousChecksum(object: object)
        }
    }

    static func deleteAll() throws {
        store.removeAll()
        try BeamObjectChecksum.deletePreviousChecksums(type: .myRemoteObject)
    }

    private func isEqual(_ object1: MyRemoteObject, to object2: MyRemoteObject) -> Bool {
        // Server side doesn't store milliseconds for updatedAt and createdAt.
        // Local coredata does, rounding using Int() to compare them

        return object1.updatedAt.intValue == object2.updatedAt.intValue &&
            object1.createdAt.intValue == object2.createdAt.intValue &&
            object1.title == object2.title &&
            object1.deletedAt?.intValue == object2.deletedAt?.intValue &&
            object1.beamObjectId == object2.beamObjectId
    }
}
