import Foundation
import BeamCore
import Promises

// MARK: Promises
extension DocumentManager {
    func create(title: String) -> Promises.Promise<DocumentStruct> {
        coreDataManager.background()
            .then(on: backgroundQueue) { context in
                try context.performAndWait {
                    let document = Document.create(context, title: title)

                    try self.checkValidations(context, document)
                    try Self.saveContext(context: context)

                    return Promise(self.parseDocumentBody(document))
                }
            }
    }

    func fetchOrCreate(title: String) -> Promises.Promise<DocumentStruct> {
        coreDataManager.background()
            .then(on: backgroundQueue) { context in
                try context.performAndWait {
                    let document = Document.fetchOrCreateWithTitle(context, title)

                    try self.checkValidations(context, document)
                    try Self.saveContext(context: context)

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

                return try context.performAndWait {
                    let document = Document.fetchOrCreateWithId(context, documentStruct.id)
                    document.update(documentStruct)
                    document.data = documentStruct.data
                    document.updated_at = BeamDate.now

                    guard !cancelme else { throw DocumentManagerError.operationCancelled }
                    try self.checkValidations(context, document)

                    guard !cancelme else { throw DocumentManagerError.operationCancelled }

                    try Self.saveContext(context: context)

                    // Ping others about the update
                    let savedDocumentStruct = DocumentStruct(document: document)
                    self.notificationDocumentUpdate(savedDocumentStruct)

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled else {
                        return Promise(true)
                    }

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
            try Document.deleteWithPredicate(CoreDataManager.shared.mainContext)
            try Self.saveContext(context: CoreDataManager.shared.mainContext)
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
                    return Promise(false)
                }

                return self.deleteFromBeamObjectAPI(id)
            }
    }

    func saveAllOnAPI() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(false)
        }

        let promise: Promise<NSManagedObjectContext> = coreDataManager.background()

        return promise.then(on: backgroundQueue) { context -> Promise<Bool> in
            let documents = try Document.rawFetchAll(context)
            Logger.shared.logDebug("Uploading \(documents.count) documents", category: .documentNetwork)
            if documents.isEmpty {
                return Promise(true)
            }

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

    @discardableResult
    func saveOnApi(_ documentStruct: DocumentStruct) -> Promise<Bool> {
        var documentStruct = documentStruct.copy()
        documentStruct.previousChecksum = documentStruct.beamObjectPreviousChecksum
        let promise: Promise<DocumentStruct> = self.saveOnBeamObjectAPI(documentStruct)
        return promise.then(on: backgroundQueue) { _ -> Promise<Bool> in
            return Promise(true)
        }
    }
}
