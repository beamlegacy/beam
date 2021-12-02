import Foundation
import BeamCore
import Promises

/*
 WARNING

 This has not been tested as much as the Foundation/callback handler code.
 */

extension DocumentManager {
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
            .then(on: backgroundQueue) { context -> Promises.Promise<Bool>  in
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

                    // Ping others about the update
                    let savedDocumentStruct = DocumentStruct(document: document)
                    self.notificationDocumentUpdate(savedDocumentStruct)

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled else {
                        return Promise(true)
                    }

                    /*
                     Something is broken around here, but I'll leave it as it is for now since promises are not used for
                     saving documents yet.

                     The completionHandler save() allows to get 2 handlers: one for saving, one for network call. The
                     promise version doesn't give any way to receive callbacks for network calls.
                     */

                    self.saveAndThrottle(savedDocumentStruct)

                    return Promise(true)
                }
            }.always {
                self.saveDocumentPromiseCancels[documentStruct.id] = nil
            }

        return result
    }

    func deleteAll(includedRemote: Bool = true) -> Promise<Bool> {
        do {
            try deleteAll(databaseId: nil)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }

        guard includedRemote else {
            return Promise(true)
        }

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(false)
        }
        Self.cancelAllPreviousThrottledAPICall()

        return deleteAllFromBeamObjectAPI()
    }

    func delete(id: UUID, _ networkDelete: Bool = true) -> Promise<Bool> {
        Self.cancelPreviousThrottledAPICall(id)

        return coreDataManager.background()
            .then(on: backgroundQueue) { context -> Promise<Bool> in
                let documentManager = DocumentManager()
                return try documentManager.context.performAndWait {
                    guard let document = try? documentManager.fetchWithId(id) else {
                        throw DocumentManagerError.idNotFound
                    }

                    if let database = try? Database.fetchWithId(context, document.database_id) {
                        database.updated_at = BeamDate.now
                    } else {
                        // We should always have a connected database
                        Logger.shared.logError("No connected database", category: .document)
                    }

                    let documentStruct = DocumentStruct(document: document)
                    document.delete(documentManager.context)

                    try documentManager.saveContext()

                    self.notificationDocumentDelete(documentStruct)

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled,
                          networkDelete else {
                        return Promise(false)
                    }

                    return self.deleteFromBeamObjectAPI(id)
                }
            }
    }

    func saveAllOnAPI() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(false)
        }

        let promise: Promise<NSManagedObjectContext> = coreDataManager.background()

        return promise.then(on: backgroundQueue) { _ -> Promise<Bool> in
            let documentManager = DocumentManager()
            return try documentManager.context.performAndWait {
                let documents = try documentManager.fetchAll(filters: [.includeDeleted])
                Logger.shared.logDebug("Uploading \(documents.count) documents", category: .documentNetwork)
                if documents.isEmpty {
                    return Promise(true)
                }

                // Cancel previous saves as we're saving all of the objects anyway
                Self.cancelAllPreviousThrottledAPICall()

                let documentStructs = documents.map { DocumentStruct(document: $0) }
                let savePromise: Promise<[DocumentStruct]> = self.saveOnBeamObjectsAPI(documentStructs)

                return savePromise.then(on: self.backgroundQueue) { savedDocumentStructs -> Promise<Bool> in
                    guard savedDocumentStructs.count == documents.count else {
                        return Promise(false)
                    }
                    return Promise(true)
                }
            }
        }
    }

    func saveOnApi(_ documentStruct: DocumentStruct) -> Promise<Bool> {
        var documentStruct = documentStruct.copy()
        documentStruct.previousChecksum = documentStruct.beamObjectPreviousChecksum
        let document_id = documentStruct.id
        let promise: Promise<DocumentStruct> = self.saveOnBeamObjectAPI(documentStruct)
        return promise.then(on: backgroundQueue) { _ -> Promise<Bool> in
            Self.networkTasksSemaphore.wait()
            Self.networkTasks.removeValue(forKey: document_id)
            Self.networkTasksSemaphore.signal()

            return Promise(true)
        }
    }
}
