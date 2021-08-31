import Foundation
import BeamCore
import PromiseKit

// MARK: PromiseKit
extension DocumentManager {
    func create(title: String) -> Promise<DocumentStruct> {
        let promise: PromiseKit.Guarantee<NSManagedObjectContext> = coreDataManager.background()
        return promise
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
        return coreDataManager.background()
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
}
