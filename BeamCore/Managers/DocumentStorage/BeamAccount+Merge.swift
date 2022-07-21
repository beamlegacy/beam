//
//  BeamAccount+Merge.swift
//  Beam
//
//  Created by Jérôme Blondon on 23/06/2022.
//

import Foundation
import BeamCore

extension BeamAccount {
    //swiftlint:disable:next cyclomatic_complexity function_body_length
    func mergeAllDatabases(initialDBs: Set<BeamDatabase>) {
        // We have just synced all the databases
        // We now need to check if a new database was added from the sync and move all the notes to it
        let allDatabases = self.allDatabases
        let syncedDatabases = allDatabases.filter { !initialDBs.contains($0) }
        let strictlyLocalDatabases = initialDBs.filter { !syncedDatabases.contains($0) }

        var databasesToDelete: [BeamDatabase] = []

        // Basically strictlyLocalDBs are the DBs that are not from the sync and syncedDBs are the one that comes from the sync
        // In the end we must have ONLY ONE DB. We will take the one that has the most notes from the sync and make it current. If syncedDBs is empty them we take the local DB that has the most notes and make it current.
        // We then move all the notes to the current DB and DESTROY all the other DBs.
        // If the other DB comes from the Sync they are soft deleted, if the other DB is strictly local, it is hard deleted

        Logger.shared.logInfo("mergeAllDatabases: initialDBs: \(initialDBs.map { $0.id })", category: .sync)
        Logger.shared.logInfo("mergeAllDatabases: allDatabases: \(allDatabases.map { $0.id })", category: .sync)
        Logger.shared.logInfo("mergeAllDatabases: syncedDatabases: \(syncedDatabases.map { $0.id })", category: .sync)
        Logger.shared.logInfo("mergeAllDatabases: strictlyLocalDatabases: \(strictlyLocalDatabases.map { $0.id })", category: .sync)

        var newDefaultDB: BeamDatabase?
        if !syncedDatabases.isEmpty && !syncedDatabases.contains(defaultDatabase) {
            // The default database is not synced. So we need to change it to the one that has the most notes:
            Logger.shared.logInfo("The default database is not synced. So we need to change it to the one that has the most notes", category: .sync)
            var noteCount = 0
            for db in syncedDatabases {
                let count = db.recordsCount()
                Logger.shared.logInfo("Database \(db) contains \(count) record(s)", category: .sync)
                if count >= noteCount {
                    noteCount = count
                    newDefaultDB = db
                }
            }
        }

        if newDefaultDB == nil {
            // We haven't found a suitable default DB, let's use a local one:
            Logger.shared.logInfo("We haven't found a suitable default synced DB, let's use a local one", category: .sync)
            var noteCount = 0
            for db in strictlyLocalDatabases {
                let count = db.recordsCount()
                Logger.shared.logInfo("Database \(db) contains \(count) record(s)", category: .sync)
                if count >= noteCount {
                    noteCount = count
                    newDefaultDB = db
                }
            }
        }

        if let newDefaultDB = newDefaultDB {
            if !newDefaultDB.isLoaded {
                do {
                    try newDefaultDB.load()
                } catch {
                    Logger.shared.logInfo("Error while loading default database \(newDefaultDB): \(error)", category: .database)
                }
            }
            Logger.shared.logInfo("New default database will be \(newDefaultDB)", category: .sync)
            // We have a new current DB so let's merge all other dbs notes & files to the current DB:
            allDatabases.filter {
                $0.id != newDefaultDB.id
            }.forEach { source in
                let destination = newDefaultDB
                Logger.shared.logInfo("Merging \(source) into \(destination)", category: .sync)

                do {
                    try moveFiles(source, destination)
                    let movedDocuments = try moveDocuments(source, destination)
                    try moveNoteFrecencies(source, destination, movedDocuments)

                    databasesToDelete.append(source)
                } catch {
                    Logger.shared.logError("Cannot copy \(source) into \(destination): \(error.localizedDescription)", category: .database)
                }
            }

            // set new database
            if let currentDatabase = BeamData.shared.currentDatabase {
                if currentDatabase != newDefaultDB {
                    do {
                        try BeamData.shared.setCurrentDatabase(newDefaultDB)
                        try newDefaultDB.save(self)
                    } catch {
                        Logger.shared.logInfo("Cannot set \(newDefaultDB) as default database: \(error)", category: .database)
                    }
                }
            } else {
                do {
                    try BeamData.shared.setCurrentDatabase(newDefaultDB)
                    try newDefaultDB.save(self)
                } catch {
                    Logger.shared.logInfo("Cannot set \(newDefaultDB) as default database: \(error)", category: .database)
                }
            }
        }

        do {
            try databasesToDelete.forEach {
                Logger.shared.logInfo("Deleting \($0)", category: .sync)
                try self.deleteDatabase($0.id)
            }
        } catch {
            Logger.shared.logError("Cannot delete databases: \(error)", category: .sync)
        }
    }

    func deleteEmptyDatabases() throws {
        guard let currentDatabase = BeamData.shared.currentDatabase else { return }

        try allDatabases.filter {
            $0.id != currentDatabase.id
        }.forEach { database in
            try database.load()
            let recordCount = database.recordsCount()
            if recordCount == 0 {
                Logger.shared.logInfo("Deleting empty database \(database)", category: .database)
                try self.deleteDatabase(database.id)
            }
        }
    }

    fileprivate func moveDocuments(_ source: BeamDatabase, _ destination: BeamDatabase) throws -> [BeamDocument] {
        var movedDocuments: [BeamDocument] = []

        assert(source !== destination)
        if !source.isLoaded {
            _ = try source.account?.loadDatabase(source.id)
        }
        assert(source.isLoaded)
        assert(destination.isLoaded)
        if let documents = try source.collection?.fetch() {
            Logger.shared.logInfo("Moving \(documents.count) document(s) from \(source) into \(destination)", category: .sync)
            try self.documentSynchroniser?.receivedObjects(documents, destination: destination)

            movedDocuments = documents
        }

        return movedDocuments
    }

    fileprivate func moveFiles(_ source: BeamDatabase, _ destination: BeamDatabase) throws {
        guard let fileDBManager = source.fileDBManager else { return }

        let count = source.filesCount()
        Logger.shared.logInfo("Adding \(count) file(s) into \(destination)", category: .sync)

        let fileRecords = try fileDBManager.allRecords()
        try destination.fileDBManager?.receivedObjects(fileRecords)
        Logger.shared.logInfo("The following files will be deleted on source: \(fileRecords)", category: .sync)
        fileDBManager.deleteAll(includedRemote: false)
    }

    fileprivate func moveNoteFrecencies(_ source: BeamDatabase, _ destination: BeamDatabase, _ deletedDocuments: [BeamDocument]) throws {
        guard let sourceManager = source.noteLinksAndRefsManager else { return }
        guard let destinationManager = destination.noteLinksAndRefsManager else { return }

        let deletedDocumentIds = deletedDocuments.map { $0.id }

        let frecencies = try sourceManager.allNoteFrecencies(updatedSince: nil).filter {
            $0.deletedAt == nil && !deletedDocumentIds.contains($0.noteId)
        }
        Logger.shared.logInfo("Moving the following frecencies: \(frecencies.map { $0.id })", category: .sync)

        try GRDBNoteFrecencyStorage(db: destinationManager).receivedObjects(frecencies)

        // remove from original source
        try sourceManager.clearNoteFrecencies()
    }

}
