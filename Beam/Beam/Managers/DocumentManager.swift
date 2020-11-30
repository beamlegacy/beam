import Foundation
import CoreData

public struct DocumentStruct {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let data: Data
}

class DocumentManager {
    var coreDataManager: CoreDataManager
    let mainContext: NSManagedObjectContext

    init(coreDataManager: CoreDataManager? = nil) {
        self.coreDataManager = coreDataManager ?? CoreDataManager.shared
        self.mainContext = self.coreDataManager.mainContext
    }

    func saveDocument(id: UUID, title: String, data: Data, completion: (() -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { context in
            let document = Document.fetchWithId(context, id) ?? Document(context: context)

            document.id = id
            document.data = data
            document.title = title

            do {
                try CoreDataManager.save(context)
                Logger.shared.logDebug("CoreDataManager saved", category: .coredata)
            } catch {
                Logger.shared.logError("Couldn't save context: \(error.localizedDescription)", category: .coredata)
            }

            completion?()
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

    private func parseDocumentBody(_ document: Document) -> DocumentStruct? {
        guard let data = document.data else { return nil }

        return DocumentStruct(id: document.id,
                              title: document.title,
                              createdAt: document.created_at,
                              updatedAt: document.updated_at,
                              data: data)

    }

    func deleteDocument(id: UUID, completion: (() -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { context in
            let document = Document.fetchWithId(context, id)
            document?.delete(context)
            completion?()
        }
    }
}
