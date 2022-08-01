//
//  BeamDatabaseSynchronizer.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/05/2022.
//

import Foundation
import BeamCore
import Combine

class BeamDatabaseSynchronizer: BeamObjectManagerDelegate, BeamDocumentSource {
    var changedObjects: [UUID: BeamDatabase] = [:]
    let objectQueue = BeamObjectQueue<BeamDatabase>()

    static var beamObjectType = BeamObjectObjectType.database
    public static var sourceId: String { "\(Self.self)" }
    weak public private(set) var account: BeamAccount?

    public private(set) static var conflictPolicy = BeamObjectConflictResolution.fetchRemoteAndError

    private var scope = Set<AnyCancellable>()

    init(account: BeamAccount) {
        self.account = account

        setupObservers()
    }

    func receivedObjects(_ objects: [BeamDatabase]) throws {
        guard let account = account else { return }
        // Then look for the database and update it, or create it if not found
        for db in objects {
            guard let database = try? account.loadDatabase(db.id) else {
                if db.deletedAt == nil {
                    try account.addDatabase(db)
                }
                continue
            }

            if database.deletedAt != db.deletedAt {
                database.deletedAt = db.deletedAt

                if database.deletedAt != nil {
                    // unload the database
                    try account.deleteDatabase(database.id)
                    continue
                }
            }

            database.account = account
            database.title = db.title
            database.createdAt = db.createdAt
            database.updatedAt = db.updatedAt

            try database.save(self)
        }
    }

    func allObjects(updatedSince: Date?) throws -> [BeamDatabase] {
        guard let values = account?.databases.values else { return [] }
        return Array(values)
    }

    func willSaveAllOnBeamObjectApi() {
    }

    func manageConflict(_ object: BeamDatabase, _ remoteObject: BeamDatabase) throws -> BeamDatabase {
        object
    }

    func saveObjectsAfterConflict(_ objects: [BeamDatabase]) throws {
        try receivedObjects(objects)
    }

    func setupObservers() {
        BeamDatabase.databaseSaved
            .filter { [weak self] in $0.account === self?.account && $0.source != self?.sourceId }
            .sink { [weak self] database in
                Task.init { [weak self] in
                    do {
                        Logger.shared.logError("Previous checksum for \(database) is: \(database.previousChecksum)", category: .database)
                        try await self?.saveOnBeamObjectAPI(database)
                    } catch {
                        Logger.shared.logError("Failed to send database \(database) to remote sync: \(error)", category: .database)
                    }
                }
            }.store(in: &scope)

        BeamDatabase.databaseDeleted
            .filter { [weak self] in $0.account === self?.account && $0.source != self?.sourceId }
            .sink { [weak self] deletedDatabase in
                Task.init { [weak self] in
                    let database = deletedDatabase.database
                    Logger.shared.logError("Previous checksum for \(database) is? \(database.previousChecksum)", category: .database)
                    if database.hasBeenSyncedOnce {
                        do {
                            Logger.shared.logInfo("Sending delete database to server \(database)", category: .database)
                            try BeamObjectChecksum.deletePreviousChecksum(object: database)
                            database.deletedAt = BeamDate.now
                            database.updatedAt = BeamDate.now
                            try await self?.saveOnBeamObjectAPI(database)
                        } catch {
                            Logger.shared.logError("Failed to send database \(database) to remote sync? \(error)", category: .database)
                        }
                    }
                }
            }.store(in: &scope)
    }
}
