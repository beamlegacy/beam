import Foundation
import BeamCore
import PromiseKit

/*
 WARNING

 This has not been tested as much as the Foundation/callback handler code.
 */

extension DocumentManager {
    func create(id: UUID, title: String) -> Promise<DocumentStruct> {
        coreDataManager.background()
            .then(on: backgroundQueue) { _ -> Promise<DocumentStruct> in
                let documentManager = DocumentManager()
                return try documentManager.context.performAndWait {
                    let document: Document = try documentManager.create(id: id, title: title, deletedAt: nil)
                    return .value(documentManager.parseDocumentBody(document))
                }
            }
    }

    func fetchOrCreate(title: String) -> Promise<DocumentStruct> {
        coreDataManager.background()
            .then(on: backgroundQueue) { _ -> Promise<DocumentStruct> in
                let documentManager = DocumentManager()
                return documentManager.context.performAndWait {
                    do {
                        let document: Document = try documentManager.fetchOrCreate(title, deletedAt: nil)
                        return .value(documentManager.parseDocumentBody(document))
                    } catch {
                        return Promise<DocumentStruct>(error: error)
                    }
                }
            }
    }

    func save(_ documentStruct: DocumentStruct) -> Promise<Bool> {
        let promise: Guarantee<NSManagedObjectContext> = coreDataManager.background()
        var cancelme = false
        let cancel = { cancelme = true }

        // Cancel previous promise
        saveDocumentPromiseCancels[documentStruct.id]?()
        saveDocumentPromiseCancels[documentStruct.id] = cancel

        let result = promise
            .then(on: self.backgroundQueue) { context -> Promise<Bool> in
                let documentManager = DocumentManager()
                return try documentManager.context.performAndWait {
                    Logger.shared.logDebug("Saving \(documentStruct.titleAndId)", category: .document)
                    Logger.shared.logDebug(documentStruct.data.asString ?? "-", category: .documentDebug)

                    guard !cancelme else { throw PMKError.cancelled }

                    let document: Document = try documentManager.fetchOrCreate(documentStruct.id, title: documentStruct.title, deletedAt: documentStruct.deletedAt)
                    document.update(documentStruct)
                    document.data = documentStruct.data
                    document.updated_at = BeamDate.now

                    guard !cancelme else { throw PMKError.cancelled }
                    try documentManager.checkValidations(document)

                    guard !cancelme else { throw PMKError.cancelled }

                    document.version = documentStruct.version

                    if let database = try? Database.fetchWithId(context, document.database_id) {
                        database.updated_at = BeamDate.now
                    } else {
                        // We should always have a connected database
                        Logger.shared.logError("Didn't find database \(document.database_id)", category: .document)
                    }

                    try documentManager.saveContext()

                    let savedDocumentStruct = DocumentStruct(document: document)

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled else {
                        return .value(true)
                    }

                    /*
                     Something is broken around here, but I'll leave it as it is for now since promises are not used for
                     saving documents yet.

                     The completionHandler save() allows to get 2 handlers: one for saving, one for network call. The
                     promise version doesn't give any way to receive callbacks for network calls.
                     */

                    self.saveAndThrottle(savedDocumentStruct)

                    return .value(true)
                }
            }.ensure {
                self.saveDocumentPromiseCancels[documentStruct.id] = nil
            }

        return result
    }

    func deleteAll(includedRemote: Bool = true) -> Promise<Bool> {
        do {
            let documentManager = DocumentManager()
            try documentManager.deleteAll(databaseId: nil)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }

        guard includedRemote else {
            return .value(true)
        }

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return .value(false)
        }
        Self.cancelAllPreviousThrottledAPICall()

        return deleteAllFromBeamObjectAPI()
    }

    func delete(document: DocumentStruct, _ networkDelete: Bool = true) -> Promise<Bool> {
        Self.cancelPreviousThrottledAPICall(document.id)

        return coreDataManager.background()
            .then(on: backgroundQueue) { context -> Promise<Bool> in
                let documentManager = DocumentManager()
                return try documentManager.context.performAndWait {
                    guard let cdDocument = try? documentManager.fetchWithId(document.id) else {
                        throw DocumentManagerError.idNotFound
                    }

                    if let database = try? Database.fetchWithId(context, cdDocument.database_id) {
                        database.updated_at = BeamDate.now
                    } else {
                        // We should always have a connected database
                        Logger.shared.logError("No connected database", category: .document)
                    }

                    let documentStruct = DocumentStruct(document: cdDocument)
                    documentManager.context.delete(cdDocument)
                    try documentManager.saveContext()

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled,
                          networkDelete else {
                        return .value(false)
                    }

                    return self.deleteFromBeamObjectAPI(objects: [documentStruct])
                }
            }
    }

    func saveAllOnAPI() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return .value(false)
        }

        let promise: Guarantee<NSManagedObjectContext> = coreDataManager.background()

        return promise.then(on: backgroundQueue) { _ -> Promise<Bool> in
            let documentManager = DocumentManager()
            return try documentManager.context.performAndWait {
                let documents = try documentManager.fetchAll(filters: [.includeDeleted])
                Logger.shared.logDebug("Uploading \(documents.count) documents", category: .documentNetwork)
                if documents.isEmpty {
                    return .value(true)
                }

                // Cancel previous saves as we're saving all of the objects anyway
                Self.cancelAllPreviousThrottledAPICall()

                let documentStructs = documents.map { DocumentStruct(document: $0) }
                let savePromise: Promise<[DocumentStruct]> = self.saveOnBeamObjectsAPI(documentStructs)

                return savePromise.then(on: self.backgroundQueue) { savedDocumentStructs -> Promise<Bool> in
                    guard savedDocumentStructs.count == documents.count else {
                        return .value(false)
                    }
                    return .value(true)
                }
            }
        }
    }

    func saveOnApi(_ documentStruct: DocumentStruct) -> Promise<Bool> {
        let document_id = documentStruct.id
        let promise: Promise<DocumentStruct> = self.saveOnBeamObjectAPI(documentStruct)
        return promise.then(on: backgroundQueue) { _ -> Promise<Bool> in
            Self.networkTasksSemaphore.wait()
            Self.networkTasks.removeValue(forKey: document_id)
            Self.networkTasksSemaphore.signal()

            return .value(true)
        }
    }
}
