import Foundation
import BeamCore
import PromiseKit

/*
 WARNING

 This has not been tested as much as the Foundation/callback handler code.
 */

extension DocumentManager {
    func create(title: String) -> Promise<DocumentStruct> {
        coreDataManager.background()
            .then(on: backgroundQueue) { context -> Promise<DocumentStruct> in
                try context.performAndWait {
                    let document = Document.create(context, title: title)

                    try self.checkValidations(context, document)
                    try Self.saveContext(context: context)

                    return .value(self.parseDocumentBody(document))
                }
            }
    }

    func fetchOrCreate(title: String) -> Promise<DocumentStruct> {
        coreDataManager.background()
            .then(on: backgroundQueue) { context -> Promise<DocumentStruct> in
                try context.performAndWait {
                    let document = Document.fetchOrCreateWithTitle(context, title)

                    try self.checkValidations(context, document)
                    try Self.saveContext(context: context)

                    return .value(self.parseDocumentBody(document))
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
                Logger.shared.logDebug("Saving \(documentStruct.titleAndId)", category: .document)
                Logger.shared.logDebug(documentStruct.data.asString ?? "-", category: .documentDebug)

                guard !cancelme else { throw PMKError.cancelled }

                return try context.performAndWait {
                    let document = Document.fetchOrCreateWithId(context, documentStruct.id)
                    document.update(documentStruct)
                    document.data = documentStruct.data
                    document.updated_at = BeamDate.now

                    guard !cancelme else { throw PMKError.cancelled }
                    try self.checkValidations(context, document)

                    guard !cancelme else { throw PMKError.cancelled }

                    document.version = documentStruct.version

                    if let database = try? Database.rawFetchWithId(context, document.database_id) {
                        database.updated_at = BeamDate.now
                    } else {
                        // We should always have a connected database
                        Logger.shared.logError("Didn't find database \(document.database_id)", category: .document)
                    }

                    try Self.saveContext(context: context)

                    // Ping others about the update
                    let savedDocumentStruct = DocumentStruct(document: document)
                    self.notificationDocumentUpdate(savedDocumentStruct)

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
            try Document.deleteWithPredicate(CoreDataManager.shared.mainContext)
            try Self.saveContext(context: CoreDataManager.shared.mainContext)
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

    func delete(id: UUID, _ networkDelete: Bool = true) -> Promise<Bool> {
        Self.cancelPreviousThrottledAPICall(id)

        return coreDataManager.background()
            .then(on: backgroundQueue) { context -> Promise<Bool> in
                guard let document = try? Document.fetchWithId(context, id) else {
                    throw DocumentManagerError.idNotFound
                }

                if let database = try? Database.rawFetchWithId(context, document.database_id) {
                    database.updated_at = BeamDate.now
                } else {
                    // We should always have a connected database
                    Logger.shared.logError("No connected database", category: .document)
                }

                let documentStruct = DocumentStruct(document: document)
                document.delete(context)

                try Self.saveContext(context: context)

                self.notificationDocumentDelete(documentStruct)

                guard AuthenticationManager.shared.isAuthenticated,
                      Configuration.networkEnabled,
                      networkDelete else {
                    return .value(false)
                }

                return self.deleteFromBeamObjectAPI(id)
            }
    }

    func saveAllOnAPI() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return .value(false)
        }

        let promise: Guarantee<NSManagedObjectContext> = coreDataManager.background()

        return promise.then(on: backgroundQueue) { context -> Promise<Bool> in
            let documents = try Document.rawFetchAll(context)
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

    func saveOnApi(_ documentStruct: DocumentStruct) -> Promise<Bool> {
        var documentStruct = documentStruct.copy()
        documentStruct.previousChecksum = documentStruct.beamObjectPreviousChecksum
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
