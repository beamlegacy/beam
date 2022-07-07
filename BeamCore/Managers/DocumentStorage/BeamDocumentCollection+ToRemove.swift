//
//  BeamDocumentCollection+ToRemove.swift
//  Beam
//
//  Created by Sebastien Metrot on 10/05/2022.
//

import Foundation
import BeamCore

public extension BeamDocumentCollection {
    private func softDeleteAll() throws {
        fatalError("Reimplement this method with GRDB!")
        #if false
        let documentManager = DocumentManager()

        let allDocuments: [BeamDocument] = (try documentManager.fetchAll(filters: filters)).compactMap { document in
            var document = BeamDocument(document: document)
            document.version += 1
            document.deletedAt = document.deletedAt ?? BeamDate.now

            let semaphore = DispatchSemaphore(value: 0)

            // TODO: REWRITE THIS ENTIRELY
            documentManager.save(document, false, nil) { _ in
                semaphore.signal()
            }

            semaphore.wait()

            return document
        }

        if !allDocuments.isEmpty {
            let semaphore = DispatchSemaphore(value: 0)

            try documentManager.saveOnBeamObjectsAPI(allDocuments) { _ in
                semaphore.signal()
            }

            semaphore.wait()
        }
        #endif
    }

    // MARK: saves
    //    static var savedCount = 0
//    @discardableResult
//    private func saveContext(file: StaticString = #file, line: UInt = #line) throws -> Bool {
//        Logger.shared.logDebug("\(self) saveContext called from \(file):\(line). hasChanges: \(context.hasChanges)",
//                               category: .document)
//
//        guard context.hasChanges else {
//            Logger.shared.logDebug("Self.saveContext: no changes!", category: .document)
//            return false
//        }
//
//        addLogLine(context.insertedObjects, name: "Inserted")
//        addLogLine(context.deletedObjects, name: "Deleted")
//        addLogLine(context.updatedObjects, name: "Updated")
//        addLogLine(context.registeredObjects, name: "Registered")
//
//        Self.savedCount += 1
//
//        do {
//            let inserted = context.insertedObjects.compactMap { $0 as? BeamDocument }
//            let updated = context.updatedObjects.compactMap { $0 as? BeamDocument }
//            let saved = Set(inserted + updated)
//            let softDeleted = Set(saved.compactMap { object -> UUID? in
//                return object.deletedAt == nil ? nil : object.id
//            })
//            let deleted = softDeleted.union(Set(context.deletedObjects.compactMap { $0 as? BeamDocument }))
//
//            // swiftlint:disable:next date_init
//            let localTimer = Date()
//            try CoreDataManager.save(context)
//            Logger.shared.logDebug("[\(Self.savedCount)] CoreDataManager saved", category: .coredata, localTimer: localTimer)
//
//            for noteSaved in saved {
//                Self.notifyDocumentSaved(noteSaved)
//            }
//
//            for noteDeleted in deleted {
//                Self.notifyDocumentDeleted(noteDeleted)
//            }
//
//            return true
//        } catch let error as NSError {
//            switch error.code {
//            case 133021:
//                // Constraint conflict
//                Logger.shared.logError("Couldn't save context because of a constraint: \(error)", category: .coredata)
//                logConstraintConflict(error)
//            case 133020:
//                // Saving a version of NSManagedObject which is outdated
//                Logger.shared.logError("Couldn't save context because the object is outdated and more recent in CoreData: \(error)",
//                                       category: .coredata)
//                logMergeConflict(error)
//            default:
//                Logger.shared.logError("Couldn't save context: \(error)", category: .coredata)
//            }
//
//            throw error
//        }
//    }

    // swiftlint:disable:next cyclomatic_complexity
//    private func logConstraintConflict(_ error: NSError) {
//        guard error.domain == NSCocoaErrorDomain, let conflicts = error.userInfo["conflictList"] as? [NSConstraintConflict] else { return }
//
//        for conflict in conflicts {
//            let conflictingDocuments: [BeamDocument] = conflict.conflictingObjects.compactMap { document in
//                return document as? BeamDocument
//            }
//            for document in conflictingDocuments {
//                Logger.shared.logError("Conflicting \(document.id), title: \(document.title), document: \(document)",
//                                       category: .coredata)
//            }
//
//            if let document = conflict.databaseObject as? BeamDocument {
//                Logger.shared.logError("Existing document \(document.id), title: \(document.title), document: \(document)",
//                                       category: .coredata)
//            }
//        }
//    }

    // swiftlint:disable:next cyclomatic_complexity
//    private func logMergeConflict(_ error: NSError) {
//        guard error.domain == NSCocoaErrorDomain, let conflicts = error.userInfo["conflictList"] as? [NSMergeConflict] else { return }
//
//        for conflict in conflicts {
//            let title = (conflict.sourceObject as? BeamDocument)?.title ?? ":( sourceObject Document Not found"
//            Logger.shared.logError("Old version: \(conflict.oldVersionNumber), new version: \(conflict.newVersionNumber), title: \(title)", category: .coredata)
//        }
//    }

}
