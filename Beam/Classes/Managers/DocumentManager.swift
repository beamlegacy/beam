import Foundation
import CoreData
import Alamofire

// swiftlint:disable file_length

public struct DocumentStruct {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    var deletedAt: Date?
    let data: Data
    let documentType: DocumentType
    var previousChecksum: String?

    var uuidString: String {
        id.uuidString.lowercased()
    }
}

extension DocumentStruct {
    init(document: Document) {
        self.id = document.id
        self.createdAt = document.created_at
        self.updatedAt = document.updated_at
        self.title = document.title
        self.documentType = DocumentType(rawValue: document.document_type) ?? .note
        self.data = document.data ?? Data()
        self.previousChecksum = document.beam_api_data?.MD5
    }

    func asApiType() -> DocumentAPIType {
        let result = DocumentAPIType(document: self)
        return result
    }
}

class DocumentManager {
    var coreDataManager: CoreDataManager
    let mainContext: NSManagedObjectContext
    let documentRequest = DocumentRequest()

    init(coreDataManager: CoreDataManager? = nil) {
        self.coreDataManager = coreDataManager ?? CoreDataManager.shared
        self.mainContext = self.coreDataManager.mainContext
    }

    func saveDocument(_ documentStruct: DocumentStruct, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        Logger.shared.logDebug("Saving \(documentStruct.title)", category: .coredata)
        coreDataManager.persistentContainer.performBackgroundTask { context in
            let document = Document.fetchOrCreateWithId(context, documentStruct.id)

            document.data = documentStruct.data
            document.title = documentStruct.title
            document.document_type = documentStruct.documentType.rawValue
            document.deleted_at = documentStruct.deletedAt

            do {
                try self.checkValidations(context, document)
            } catch {
                completion?(.failure(error))
                return
            }

            // If not authenticated, we don't need to send to BeamAPI
            guard AuthenticationManager.shared.isAuthenticated else {
                self.saveContext(context: context, completion: completion)
                return
            }

            // If authenticated
            self.saveDocumentOnAPI(context, document, completion)
        }
    }

    private func saveDocumentOnAPI(_ context: NSManagedObjectContext,
                                   _ document: Document,
                                   _ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        // Note: This will break if we call context.save before calling `saveDocumentOnAPI`
        guard context.hasChanges else { return }

        var documentStruct = DocumentStruct(document: document)
        documentStruct.previousChecksum = document.beam_api_data?.MD5
        self.documentRequest.saveDocument(documentStruct.asApiType()) { result in
            switch result {
            case .failure(let error):
                if (error as? APIRequestError) == APIRequestError.documentConflict {
                    // Saving the document on the API gave a conflict we should fix before saving it again
                    NotificationCenter.default.post(name: .apiDocumentConflict,
                                                    object: documentStruct)

                    Logger.shared.logDebug("Server rejected our update based on checksum for \(documentStruct.title), overwriting", category: .network)
                    // TODO: enforcing server overwrite for now by disabling checksum, but we should display a
                    // conflict window and suggest to the user to keep a version or another
                    context.refresh(document, mergeChanges: false)
                    document.beam_api_data = nil
                    context.perform {
                        self.saveDocumentOnAPI(context, document, completion)
                    }
                    return
                    //
                }

                context.performAndWait {
                    self.saveContext(context: context)
                    completion?(.failure(error))
                }
            case .success:
                // We save the remote stored version of the document, to know if we have local changes
                context.performAndWait {
                    document.beam_api_data = documentStruct.data
                    self.saveContext(context: context, completion: completion)
                }
            }
        }
    }

    func loadDocumentById(id: UUID) -> DocumentStruct? {
        guard let document = Document.fetchWithId(mainContext, id) else { return nil }

        return parseDocumentBody(document)
    }

    func loadDocumentByTitle(title: String) -> DocumentStruct? {
        guard let document = Document.fetchWithTitle(mainContext, title) else { return nil }

        return parseDocumentBody(document)
    }

    func loadDocumentsWithType(type: DocumentType) -> [DocumentStruct] {
        return Document.fetchAllWithType(mainContext, type.rawValue).compactMap { document -> DocumentStruct? in
            parseDocumentBody(document)
        }
    }

    func documentsWithTitleMatch(title: String) -> [DocumentStruct] {
        return Document.fetchAllWithTitleMatch(mainContext, title).compactMap { document -> DocumentStruct? in
            parseDocumentBody(document)
        }
    }

    func documentsWithLimitTitleMatch(title: String, limit: Int = 4) -> [DocumentStruct] {
        return Document.fetchAllWithLimitedTitleMatch(mainContext, title, limit).compactMap { document -> DocumentStruct? in
            parseDocumentBody(document)
        }
    }

    func loadAllDocumentsWithLimit(_ limit: Int = 4) -> [DocumentStruct] {
        return Document.fetchAllWithLimitResult(mainContext, limit).compactMap { document -> DocumentStruct? in
            parseDocumentBody(document)
        }
    }

    func loadDocuments() -> [DocumentStruct] {
        return Document.fetchAll(context: mainContext).compactMap { document in
            parseDocumentBody(document)
        }
    }

    private func parseDocumentBody(_ document: Document) -> DocumentStruct? {
        guard let data = document.data else { return nil }
        guard let type = DocumentType(rawValue: document.document_type) else { return nil }

        return DocumentStruct(id: document.id,
                              title: document.title,
                              createdAt: document.created_at,
                              updatedAt: document.updated_at,
                              deletedAt: document.deleted_at,
                              data: data,
                              documentType: type)
    }

    func deleteDocument(id: UUID, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { context in
            let document = Document.fetchWithId(context, id)
            document?.delete(context)

            // If not authenticated
            guard AuthenticationManager.shared.isAuthenticated else {
                completion?(.success(true))
                return
            }

            // If authenticated
            self.documentRequest.deleteDocument(id.uuidString.lowercased()) { result in
                switch result {
                case .failure(let error):
                    completion?(.failure(error))
                case .success:
                    completion?(.success(true))
                }
            }
        }
    }

    /// Fetch all remote documents from API
    // swiftlint:disable:next function_body_length
    // swiftlint:disable:next cyclomatic_complexity
    func refreshDocuments(completion: ((Result<Bool, Error>) -> Void)? = nil) {
        // If not authenticated
        guard AuthenticationManager.shared.isAuthenticated else {
            completion?(.success(true))
            return
        }

        documentRequest.fetchDocuments { result in
            switch result {
            case .failure(let error):
                completion?(.failure(error))
            case .success(let documentAPITypes):
                self.coreDataManager.persistentContainer.performBackgroundTask { context in
                    var errors: Bool = false
                    var remoteDocumentsIds: [UUID] = []
                    for documentAPIType in documentAPITypes {
                        guard let documentId = documentAPIType.id,
                              let uuid = UUID(uuidString: documentId) else {
                            errors = true
                            Logger.shared.logError("\(documentAPIType) has no id", category: .network)
                            continue
                        }
                        remoteDocumentsIds.append(uuid)

                        let document = Document.fetchOrCreateWithId(context, uuid)

                        guard self.updateDocumentWithDocumentType(document, documentAPIType) else {
                            errors = true
                            Logger.shared.logError("Document has local change! Should merge", category: .document)
                            NotificationCenter.default.post(name: .apiDocumentConflict,
                                                            object: DocumentStruct(document: document))
                            continue
                        }
                    }

                    // Deleting local documents we haven't found remotely
                    self.deleteNonExistingIds(context, remoteDocumentsIds)

                    if errors {
                        self.saveContext(context: context)
                        completion?(.success(false))
                    } else {
                        self.saveContext(context: context, completion: completion)
                    }
                }
            }
        }
    }

    /// Must be called within the context thread
    private func deleteNonExistingIds(_ context: NSManagedObjectContext, _ remoteDocumentsIds: [UUID]) {
        let documents = Document.fetchAllWithLimit(context: context, NSPredicate(format: "NOT id IN %@", remoteDocumentsIds))
        for document in documents {
            Logger.shared.logDebug("Marking \(document.title) as deleted", category: .document)
            document.deleted_at = Date()
        }
    }

    /// Fetch most recent document from API
    /// First we fetch the remote updated_at, if it's more recent we fetch all details
    // swiftlint:disable:next function_body_length
    // swiftlint:disable:next cyclomatic_complexity
    func refreshDocument(_ documentStruct: DocumentStruct, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        // If not authenticated
        guard AuthenticationManager.shared.isAuthenticated else {
            completion?(.success(true))
            return
        }

        documentRequest.fetchDocumentUpdatedAt(documentStruct.uuidString) { result in
            switch result {
            case .failure(let error):
                if (error as? AFError)?.responseCode == 404 {
                    self.deleteLocalDocument(documentStruct)
                }

                completion?(.failure(error))
            case .success(let documentType):
                // If the document we fetched from the API has a lower updatedAt, we can skip it
                guard let updatedAt = documentType.updatedAt, updatedAt > documentStruct.updatedAt else {
                    completion?(.success(false))
                    return
                }

                // Remote document is more recent, updating all the object
                self.documentRequest.fetchDocument(documentStruct.uuidString) { result in
                    switch result {
                    case .failure(let error):
                        if (error as? AFError)?.responseCode == 404 {
                            self.deleteLocalDocument(documentStruct)
                        }
                        completion?(.failure(error))
                    case .success(let documentType):
                        self.coreDataManager.persistentContainer.performBackgroundTask { context in
                            guard let document = Document.fetchWithId(context, documentStruct.id) else {
                                completion?(.success(false))
                                return
                            }

                            guard self.updateDocumentWithDocumentType(document, documentType) else {
                                completion?(.success(false))
                                Logger.shared.logError("Document has local change! Should merge", category: .document)
                                NotificationCenter.default.post(name: .apiDocumentConflict,
                                                                object: DocumentStruct(document: document))
                                return
                            }

                            self.saveContext(context: context, completion: completion)
                        }
                    }
                }
            }
        }
    }

    private func deleteLocalDocument(_ documentStruct: DocumentStruct) {
        self.coreDataManager.persistentContainer.performBackgroundTask { context in
            guard let document = Document.fetchWithId(context, documentStruct.id) else {
                return
            }

            document.deleted_at = Date()

            self.saveContext(context: context)
        }
    }

    /// Update local coredata instance with data we fetched remotely
    private func updateDocumentWithDocumentType(_ document: Document, _ documentType: DocumentAPIType) -> Bool {
        // TODO: Try to merge before returning false
        guard !document.hasLocalChanges else { return false }

        document.title = documentType.title ?? document.title
        document.created_at = documentType.createdAt ?? document.created_at
        document.updated_at = documentType.updatedAt ?? document.updated_at
        document.document_type = documentType.documentType ?? document.document_type
        if let stringData = documentType.data {
            document.data = Data(stringData.utf8)
        }

        return true
    }

    // swiftlint:disable:next cyclomatic_complexity
    func deleteAllDocuments(includedRemote: Bool = true, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        CoreDataManager.shared.destroyPersistentStore {
            CoreDataManager.shared.setup()

            guard includedRemote else {
                completion?(.success(true))
                return
            }

            self.documentRequest.deleteAllDocuments { result in
                switch result {
                case .failure(let error):
                    completion?(.failure(error))
                case .success:
                    completion?(.success(true))
                }
            }
        }
    }

    func uploadAllDocuments(_ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) {
        CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
            let documents = Document.fetchAll(context: context)
            let documentsArray: [DocumentAPIType] = documents.map { document in document.asApiType() }

            self.documentRequest.importDocuments(documentsArray) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .network)
                    completionHandler?(.failure(error))
                case .success:
                    Logger.shared.logDebug("Documents imported", category: .network)
                    completionHandler?(.success(true))
                }
            }
        }
    }

    private func saveContext(context: NSManagedObjectContext, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard context.hasChanges else { completion?(.success(true)); return }

        do {
            try CoreDataManager.save(context)
            Logger.shared.logDebug("CoreDataManager saved", category: .coredata)
            completion?(.success(true))
        } catch let error as NSError {
            switch error.code {
            case 133021:
                // Constraint conflict
                Logger.shared.logError("Couldn't save context because of a constraint: \(error)", category: .coredata)
                logConstraintConflict(error)
            case 133020:
                // Saving a version of NSManagedObject which is outdated
                Logger.shared.logError("Couldn't save context because the object is outdated and more recent in CoreData: \(error)", category: .coredata)
                logMergeConflict(error)
            default:
                Logger.shared.logError("Couldn't save context: \(error)", category: .coredata)
            }

            completion?(.failure(error))
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func logConstraintConflict(_ error: NSError) {
        guard error.domain == NSCocoaErrorDomain, let conflicts = error.userInfo["conflictList"] as? [NSConstraintConflict] else { return }

        for conflict in conflicts {
            let conflictingDocuments: [Document] = conflict.conflictingObjects.compactMap { document in
                return document as? Document
            }
            for document in conflictingDocuments {
                Logger.shared.logError("Conflicting \(document.id), title: \(document.title), document: \(document)",
                                       category: .coredata)
            }

            if let document = conflict.databaseObject as? Document {
                Logger.shared.logError("Existing document \(document.id), title: \(document.title), document: \(document)",
                                       category: .coredata)
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func logMergeConflict(_ error: NSError) {
        guard error.domain == NSCocoaErrorDomain, let conflicts = error.userInfo["conflictList"] as? [NSMergeConflict] else { return }

        for conflict in conflicts {
            let title = (conflict.sourceObject as? Document)?.title ?? ":( Not found"
            Logger.shared.logError("Old version: \(conflict.oldVersionNumber), new version: \(conflict.newVersionNumber), title: \(title)", category: .coredata)
        }
    }

    // MARK: -
    // MARK: Validations
    private func checkValidations(_ context: NSManagedObjectContext, _ document: Document) throws {
        try checkDuplicateTitles(context, document)
    }

    private func checkDuplicateTitles(_ context: NSManagedObjectContext, _ document: Document) throws {
        // If document is deleted, we don't need to check title uniqueness
        guard document.deleted_at == nil else { return }

        let predicate = NSPredicate(format: "title = %@ AND id != %@", document.title, document.id as CVarArg)

        if Document.countWithPredicate(context, predicate) > 0 {
            let errString = "Title is already used in another document"
            let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString, NSValidationObjectErrorKey: self]
            throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1001, userInfo: userInfo)
        }
    }
}

// swiftlint:enable file_length
