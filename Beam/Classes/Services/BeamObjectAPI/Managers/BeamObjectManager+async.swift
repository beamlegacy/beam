import Foundation
import BeamCore
import Atomics

// MARK: - BeamObjectProtocol (local checksum persistence only; no remote Beam API)

extension BeamObjectManager {
    @discardableResult
    func saveToAPI<T: BeamObjectProtocol>(_ objects: [T],
                                          force: Bool = false,
                                          requestUploadType: BeamObjectRequestUploadType? = nil,
                                          conflictPolicy: BeamObjectConflictResolution) async throws -> [T] {
        try await persistBeamObjectsLocally(objects, force: force)
    }

    func saveToAPIClassic<T: BeamObjectProtocol>(_ objects: [T],
                                                 force: Bool = false,
                                                 maxChunk: Int = 1000,
                                                 conflictPolicy: BeamObjectConflictResolution) async throws -> [T] {
        try await persistBeamObjectsLocally(objects, force: force)
    }

    private func persistBeamObjectsLocally<T: BeamObjectProtocol>(_ objects: [T], force: Bool) async throws -> [T] {
        guard !objects.isEmpty else { return [] }

        let beamObjects: [BeamObject] = try objects.map { try BeamObject(object: $0) }
        let toSave = force ? beamObjects : updatedObjectsOnly(beamObjects)
        guard !toSave.isEmpty else { return objects }

        let checksums = BeamObjectChecksum.previousChecksums(beamObjects: toSave)
        toSave.forEach { $0.previousChecksum = checksums[$0] }

        try BeamObjectChecksum.savePreviousChecksums(beamObjects: toSave)
        try BeamObjectChecksum.savePreviousObjects(beamObjects: toSave)
        return objects
    }

    @discardableResult
    func saveToAPI<T: BeamObjectProtocol>(_ object: T,
                                          force: Bool = false,
                                          requestUploadType: BeamObjectRequestUploadType? = nil,
                                          conflictPolicy: BeamObjectConflictResolution) async throws -> T {
        guard !disableSendingObjects || force else {
            throw BeamObjectManagerError.sendingObjectsDisabled
        }
        _ = try await persistBeamObjectsLocally([object], force: force)
        return object
    }

    func saveToAPIClassic<T: BeamObjectProtocol>(_ object: T,
                                                 force: Bool = false,
                                                 conflictPolicy: BeamObjectConflictResolution) async throws -> T {
        guard !disableSendingObjects || force else {
            throw BeamObjectManagerError.sendingObjectsDisabled
        }
        let beamObject = try BeamObject(object: object)
        beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)

        guard beamObject.previousChecksum != beamObject.dataChecksum || beamObject.previousChecksum == nil || force else {
            return object
        }

        try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
        try BeamObjectChecksum.savePreviousObject(beamObject: beamObject)
        return object
    }

    func saveToAPIWithDirectUpload<T: BeamObjectProtocol>(_ object: T,
                                                          force: Bool = false,
                                                          conflictPolicy: BeamObjectConflictResolution) async throws -> T {
        try await saveToAPIClassic(object, force: force, conflictPolicy: conflictPolicy)
    }

    func fetchObjects<T: BeamObjectProtocol>(_ objects: [T],
                                             storePreviousChecksum: Bool = false) async throws -> [T] {
        []
    }

    @discardableResult
    func fetchAllObjects<T: BeamObjectProtocol>(raisePrivateKeyError: Bool = false) async throws -> [T] {
        []
    }

    @discardableResult
    func fetchObject<T: BeamObjectProtocol>(_ object: T) async throws -> T {
        throw APIRequestError.notFound
    }

    func fetchObjectUpdatedAt<T: BeamObjectProtocol>(_ object: T) async throws -> Date? {
        nil
    }

    func fetchObjectChecksum<T: BeamObjectProtocol>(_ object: T) async throws -> String? {
        nil
    }
}

// MARK: - BeamObject
extension BeamObjectManager {
    @discardableResult
    func saveToAPI(_ beamObjects: [BeamObject],
                   deep: Int = 0,
                   conflictPolicy: BeamObjectConflictResolution) async throws -> [BeamObject] {
        guard !disableSendingObjects else {
            throw BeamObjectManagerError.sendingObjectsDisabled
        }
        guard deep < 3 else {
            throw BeamObjectManagerError.nestedTooDeep
        }

        let checksums = BeamObjectChecksum.previousChecksums(beamObjects: beamObjects)
        beamObjects.forEach { $0.previousChecksum = checksums[$0] }

        let toSave = updatedObjectsOnly(beamObjects)
        guard !toSave.isEmpty else { return beamObjects }

        try BeamObjectChecksum.savePreviousChecksums(beamObjects: toSave)
        try BeamObjectChecksum.savePreviousObjects(beamObjects: toSave)
        return beamObjects
    }

    func saveToAPI(_ beamObject: BeamObject, deep: Int = 0, conflictPolicy: BeamObjectConflictResolution) async throws -> BeamObject {
        guard !disableSendingObjects else {
            throw BeamObjectManagerError.sendingObjectsDisabled
        }
        guard deep < 3 else {
            throw BeamObjectManagerError.nestedTooDeep
        }

        beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(beamObject: beamObject)

        guard beamObject.previousChecksum != beamObject.dataChecksum || beamObject.previousChecksum == nil else {
            return beamObject
        }

        try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
        try BeamObjectChecksum.savePreviousObject(beamObject: beamObject)
        return beamObject
    }

    internal func fetchBeamObjects<T: BeamObjectProtocol>(objects: [T]) async throws -> [BeamObject] {
        []
    }

    internal func fetchBeamObjects(_ beamObjects: [BeamObject]) async throws -> [BeamObject] {
        []
    }

    internal func fetchBeamObjects(_ ids: [UUID]) async throws -> [BeamObject] {
        []
    }

    internal func asyncFetchBeamObjectChecksums(_ ids: [UUID]) async throws -> [BeamObject] {
        []
    }

    internal func fetchBeamObjects(_ beamObjectType: String,
                                   raisePrivateKeyError: Bool = false) async throws -> [BeamObject] {
        []
    }

    internal func fetchBeamObject(beamObject: BeamObject) async throws -> BeamObject {
        throw APIRequestError.notFound
    }

    internal func fetchBeamObject<T: BeamObjectProtocol>(object: T) async throws -> BeamObject {
        throw APIRequestError.notFound
    }

    internal func fetchMinimalBeamObject(beamObject: BeamObject) async throws -> BeamObject {
        throw APIRequestError.notFound
    }

    @discardableResult
    internal func fetchMinimalBeamObject<T: BeamObjectProtocol>(object: T) async throws -> BeamObject {
        throw APIRequestError.notFound
    }

    @discardableResult
    func delete<T: BeamObjectProtocol>(object: T, raise404: Bool = false) async throws -> BeamObject? {
        try BeamObjectChecksum.deletePreviousChecksum(object: object)
        return nil
    }

    @discardableResult
    func delete(beamObject: BeamObject, raise404: Bool = false) async throws -> BeamObject? {
        try BeamObjectChecksum.deletePreviousChecksum(beamObject: beamObject)
        return nil
    }

    @discardableResult
    func deleteAll(_ beamObjectType: BeamObjectObjectType? = nil) async throws -> Bool {
        if let beamObjectType = beamObjectType {
            try BeamObjectChecksum.deletePreviousChecksums(type: beamObjectType)
        } else {
            try BeamObjectChecksum.deleteAll()
        }
        return true
    }
}
