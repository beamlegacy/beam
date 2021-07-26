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
    typealias BeamObjectType = MyRemoteObject

    func receivedObjects(_ objects: [BeamObjectType]) throws {
        Self.receivedMyRemoteObjects.append(contentsOf: objects)
    }

    func allObjects() throws -> [BeamObjectType] {
        Array(Self.store.values)
    }

    func persistChecksum(_ objects: [BeamObjectType]) throws {
        for object in objects {
            Self.store[object.beamObjectId]?.previousChecksum = object.checksum
        }
    }

    func manageConflict(_ object: BeamObjectType,
                        _ remoteObject: BeamObjectType) throws -> BeamObjectType {
        var result = object.copy()

        result.title = "merged: "

        if let title = object.title {
            result.title = result.title! + title
        }

        if let title = remoteObject.title {
            result.title = result.title! + title
        }

        return result
    }

    func saveObjectsAfterConflict(_ objects: [BeamObjectType]) throws {
        for object in objects {
            Self.store[object.beamObjectId] = object
            Self.store[object.beamObjectId]?.previousChecksum = object.checksum
        }
    }
}
