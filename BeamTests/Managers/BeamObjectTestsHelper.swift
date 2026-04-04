import Foundation
import Quick
import Nimble

@testable import Beam
@testable import BeamCore

class BeamObjectTestsHelper {
    func fetchOnAPI(_ object: BeamObject) async -> BeamObject? {
        nil
    }

    func fetchOnAPI<T: BeamObjectProtocol>(_ object: T?) async throws -> T? {
        nil
    }

    func saveOnAPI<T: BeamObjectProtocol>(_ object: T) async -> BeamObject? {
        await saveOnAPIAndSaveChecksum(object)
    }

    @discardableResult
    func saveOnAPIAndSaveChecksum<T: BeamObjectProtocol>(_ object: T) async -> BeamObject? {
        do {
            let beamObject = try BeamObject(object)
            beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)
            try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
            try BeamObjectChecksum.savePreviousObject(beamObject: beamObject)
            return beamObject
        } catch {
            fail(error.localizedDescription)
            return nil
        }
    }

    func saveOnAPIWithDirectUploadAndSaveChecksum<T: BeamObjectProtocol>(_ object: T) async {
        await saveOnAPIAndSaveChecksum(object)
    }

    func saveOnAPI<T: BeamObjectProtocol>(_ objects: [T]) async -> [BeamObject] {
        await saveOnAPIAndSaveChecksum(objects)
    }

    @discardableResult
    func saveOnAPIAndSaveChecksum<T: BeamObjectProtocol>(_ objects: [T]) async -> [BeamObject] {
        do {
            var beamObjects: [BeamObject] = []
            for object in objects {
                let beamObject = try BeamObject(object)
                beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)
                beamObjects.append(beamObject)
            }
            try beamObjects.forEach { try BeamObjectChecksum.savePreviousChecksum(beamObject: $0) }
            try beamObjects.forEach { try BeamObjectChecksum.savePreviousObject(beamObject: $0) }
            return beamObjects
        } catch {
            fail(error.localizedDescription)
            return []
        }
    }

    func delete<T: BeamObjectProtocol>(_ object: T) async {
        do {
            try BeamObjectChecksum.deletePreviousChecksum(object: object)
        } catch {
            fail("Cannot delete checksum for object")
        }
    }

    func deleteAll(beamObjectType: BeamObjectObjectType? = nil) async {
        do {
            if let beamObjectType = beamObjectType {
                try BeamObjectChecksum.deletePreviousChecksums(type: beamObjectType)
            } else {
                try BeamObjectChecksum.deleteAll()
            }
        } catch {
            fail("Cannot delete checksums")
        }
    }
}
