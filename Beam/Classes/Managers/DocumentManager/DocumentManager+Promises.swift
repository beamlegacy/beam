import Foundation
import BeamCore
import Promises

/*
 WARNING

 This has not been tested as much as the Foundation/callback handler code.
 */

extension DocumentManager1 {
    func create(id: UUID, title: String) -> Promises.Promise<DocumentStruct> {
        coreDataManager.background()
            .then(on: backgroundQueue) { _ in
                let documentManager = DocumentManager()
                return try documentManager.context.performAndWait {
                    let document: Document = try documentManager.create(id: id, title: title, deletedAt: nil)
                    return Promise(self.parseDocumentBody(document))
                }
            }
    }

    func fetchOrCreate(title: String) -> Promises.Promise<DocumentStruct> {
        coreDataManager.background()
            .then(on: backgroundQueue) { _ in
                let documentManager = DocumentManager()
                return try documentManager.context.performAndWait {
                    let document: Document = try documentManager.fetchOrCreate(title, deletedAt: nil)
                    return Promise(self.parseDocumentBody(document))
                }
            }
    }

    func save(_ documentStruct: DocumentStruct) -> Promises.Promise<Bool> {
        let promise: Promises.Promise<NSManagedObjectContext> = coreDataManager.background()
        var cancelme = false
        let cancel = { cancelme = true }

        // Cancel previous promise
        saveDocumentPromiseCancels[documentStruct.id]?()
        saveDocumentPromiseCancels[documentStruct.id] = cancel

        let result = promise
            .then(on: saveDocumentQueue) { context -> Promises.Promise<Bool>  in
                Logger.shared.logDebug("Saving \(documentStruct.titleAndId)", category: .document)
                Logger.shared.logDebug(documentStruct.data.asString ?? "-", category: .documentDebug)

                guard !cancelme else { throw DocumentManagerError.operationCancelled }

                let documentManager = DocumentManager()
                return try documentManager.context.performAndWait {
                    let document: Document = try documentManager.fetchOrCreate(documentStruct.id, title: documentStruct.title, deletedAt: documentStruct.deletedAt)
                    document.update(documentStruct)
                    document.data = documentStruct.data
                    document.updated_at = BeamDate.now

                    guard !cancelme else { throw DocumentManagerError.operationCancelled }
                    try documentManager.checkValidations(document)

                    guard !cancelme else { throw DocumentManagerError.operationCancelled }

                    document.version = documentStruct.version

                    if let database = try? Database.fetchWithId(context, document.database_id) {
                        database.updated_at = BeamDate.now
                    } else {
                        // We should always have a connected database
                        Logger.shared.logError("Didn't find database \(document.database_id)", category: .document)
                    }
                    try documentManager.saveContext()

                    return Promise(true)
                }
            }.always {
                self.saveDocumentPromiseCancels[documentStruct.id] = nil
            }

        return result
    }

    func deleteAll() -> Promise<Bool> {
        do {
            try deleteAll(databaseId: nil)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }
        return Promise(true)
    }

    func delete(document: DocumentStruct) -> Promise<Bool> {
        Self.cancelPreviousThrottledAPICall(document.id)

        return coreDataManager.background()
            .then(on: backgroundQueue) { context -> Promise<Bool> in
                let documentManager = DocumentManager()
                return try documentManager.context.performAndWait {
                    guard let cdDocument = try? documentManager.fetchWithId(document.id, includeDeleted: true) else {
                        throw DocumentManagerError.idNotFound
                    }

                    if let database = try? Database.fetchWithId(context, cdDocument.database_id) {
                        database.updated_at = BeamDate.now
                    } else {
                        Logger.shared.logError("No connected database", category: .document)
                    }

                    documentManager.context.delete(cdDocument)
                    try documentManager.saveContext()
                    return Promise(true)
                }
            }
    }

    func saveAllOnAPI() -> Promise<Bool> {
        return Promise(true)
    }
}
