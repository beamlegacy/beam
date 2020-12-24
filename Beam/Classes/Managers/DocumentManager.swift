import Foundation
import CoreData

public struct DocumentStruct {
    let id: UUID
    let title: String
    var createdAt: Date?
    var updatedAt: Date?
    let data: Data
    let documentType: DocumentType
}

extension DocumentStruct {
    init?(id: UUID, title: String, data: Data, documentType: DocumentType) {
        self.id = id
        self.title = title
        self.data = data
        self.documentType = documentType
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
        coreDataManager.persistentContainer.performBackgroundTask { context in
            let document = Document.fetchWithId(context, documentStruct.id) ?? Document(context: context)

            document.id = documentStruct.id
            document.data = documentStruct.data
            document.title = documentStruct.title
            document.documentType = documentStruct.documentType.rawValue

            do {
                try CoreDataManager.save(context)
                Logger.shared.logDebug("CoreDataManager saved", category: .coredata)
            } catch {
                Logger.shared.logError("Couldn't save context: \(error)", category: .coredata)
                completion?(.failure(error))
                return
            }

            completion?(.success(true))

            self.documentRequest.saveDocument(documentStruct.asApiType()) { result in
                switch result {
                case .failure(let error):
                    break
                case .success:
                    break
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

    func loadDocuments() -> [DocumentStruct] {
        return Document.fetchAll(context: mainContext).compactMap { document in
            parseDocumentBody(document)
        }
    }

    private func parseDocumentBody(_ document: Document) -> DocumentStruct? {
        guard let data = document.data else { return nil }
        guard let type = DocumentType(rawValue: document.documentType) else { return nil }

        return DocumentStruct(id: document.id,
                              title: document.title,
                              createdAt: document.created_at,
                              updatedAt: document.updated_at,
                              data: data,
                              documentType: type)

    }

    func deleteDocument(id: UUID, completion: (() -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { context in
            let document = Document.fetchWithId(context, id)
            document?.delete(context)
            completion?()

            self.documentRequest.deleteDocument(id.uuidString.lowercased()) { result in
                switch result {
                case .failure(let error): break
                case .success: break
                }
            }
        }
    }

    func deleteAllDocuments(completion: ((Result<Bool, Error>) -> Void)? = nil) {
        CoreDataManager.shared.destroyPersistentStore {
            CoreDataManager.shared.setup()

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
}
