import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import BeamCore

@testable import Beam

// Minimal manager
class MyRemoteObjectManager {
    static var receivedMyRemoteObjects: [MyRemoteObject] = []
    static var store: [UUID: MyRemoteObject] = [:]
}

extension MyRemoteObjectManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace

    func receivedObjects(_ objects: [MyRemoteObject]) throws {
        Self.receivedMyRemoteObjects.append(contentsOf: objects)
    }

    func allObjects() throws -> [MyRemoteObject] {
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
            Self.store[object.beamObjectId]?.previousChecksum = object.checksum
        }
    }

    func persistChecksum(_ objects: [MyRemoteObject]) throws {
        for object in objects {
            Self.store[object.beamObjectId]?.previousChecksum = object.previousChecksum
        }
    }
}
