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
}
