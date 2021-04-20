import Foundation
import CoreData
import BeamCore

class Document: NSManagedObject {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        created_at = BeamDate.now
        updated_at = BeamDate.now
        id = UUID()
    }

    var uuidString: String {
        id.uuidString.lowercased()
    }

    var hasLocalChanges: Bool {
        // We don't have a saved previous version, it's a new document
        guard let beam_api_data = beam_api_data else { return false }

        return beam_api_data != data
    }

    func asApiType(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext) -> DocumentAPIType {
        let result = DocumentAPIType(document: self, context: context)
        return result
    }

    override func willSave() {
        let keys = self.changedValues().keys
        if updated_at.timeIntervalSince(BeamDate.now) < -1.0 {
            if keys.contains("data") {
                self.updated_at = BeamDate.now
            }
        }
        super.willSave()
    }

    func delete(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext) {
        context.delete(self)
        do {
            try context.save()
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }
    }

    func database(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext) -> Database? {
        try? Database.rawFetchWithId(context, database_id)
    }

    /// Slower than `deleteBatchWithPredicate` but I can't get `deleteBatchWithPredicate` to properly propagate changes to other contexts :(
    class func deleteWithPredicate(_ context: NSManagedObjectContext, _ predicate: NSPredicate? = nil) throws {
        let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Document")
        deleteFetch.predicate = predicate

        context.performAndWait {
            for document in Document.rawFetchAllWithLimit(context: context, predicate) {
                context.delete(document)
            }
        }
    }

    class func deleteBatchWithPredicate(_ context: NSManagedObjectContext, _ predicate: NSPredicate? = nil) throws {
        let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Document")
        deleteFetch.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)

        deleteRequest.resultType = .resultTypeObjectIDs

        try context.performAndWait {
            for document in Document.rawFetchAllWithLimit(context: context) {
                Logger.shared.logDebug("title: \(document.title) database_id: \(document.database_id)", category: .document)
            }

            Logger.shared.logDebug("About to delete \(rawCountWithPredicate(context, predicate)) documents", category: .document)

            try context.execute(deleteRequest)

            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult

            // Retrieves the IDs deleted
            guard let objectIDs = result?.result as? [NSManagedObjectID] else { return }

            Logger.shared.logDebug("objectIDs: \(objectIDs)", category: .document)
            Logger.shared.logDebug("predicate: \(String(describing: predicate))", category: .document)

            // We don't need to propagate changes if already main context
//            guard CoreDataManager.shared.mainContext != context else { return }

            // Note: this seems to be propagating the deletes to the main managedContext
            // even without this, but documentation says we should do it so...

            // Updates the main context
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes,
                                                into: [CoreDataManager.shared.mainContext])
        }
    }

    class func create(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext,
                      title: String? = nil) -> Document {
        let document = Document(context: context)
        document.id = UUID()
        document.database_id = DatabaseManager.defaultDatabase.id
        document.version = 0
        if let title = title {
            document.title = title
        }

        return document
    }

    func update(_ documentStruct: DocumentStruct) {
        database_id = documentStruct.databaseId
        data = documentStruct.data
        title = documentStruct.title
        document_type = documentStruct.documentType.rawValue
        created_at = documentStruct.createdAt
        updated_at = BeamDate.now
        deleted_at = documentStruct.deletedAt
        is_public = documentStruct.isPublic
    }

    class func countWithPredicate(_ context: NSManagedObjectContext,
                                  _ predicate: NSPredicate? = nil,
                                  _ databaseId: UUID? = nil) -> Int {
        return rawCountWithPredicate(context,
                                     predicate,
                                     databaseId ?? DatabaseManager.defaultDatabase.id,
                                     onlyNonDeleted: true)
    }

    class func rawCountWithPredicate(_ context: NSManagedObjectContext,
                                     _ predicate: NSPredicate? = nil,
                                     _ databaseId: UUID? = nil,
                                     onlyNonDeleted: Bool = false) -> Int {
        // Fetch existing if any
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()

        fetchRequest.predicate = processPredicate(predicate, databaseId, onlyNonDeleted: onlyNonDeleted)

        do {
            let fetchedTransactions = try context.count(for: fetchRequest)
            return fetchedTransactions
        } catch {
            // TODO: raise error?
            Logger.shared.logError("Can't count: \(error)", category: .coredata)
        }

        return 0
    }

    class func fetchFirst(context: NSManagedObjectContext,
                          _ predicate: NSPredicate? = nil,
                          _ sortDescriptors: [NSSortDescriptor]? = nil,
                          onlyNonDeleted: Bool = true,
                          onlyDefaultDatabase: Bool = true) -> Document? {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()

        fetchRequest.predicate = processPredicate(predicate,
                                                  onlyDefaultDatabase ? DatabaseManager.defaultDatabase.id : nil,
                                                  onlyNonDeleted: onlyNonDeleted)
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = sortDescriptors

        do {
            let fetchedDocument = try context.fetch(fetchRequest)
            return fetchedDocument.first
        } catch {
            Logger.shared.logError("Error fetching note: \(error.localizedDescription)", category: .coredata)
        }

        return nil
    }

    class func rawFetchFirst(context: NSManagedObjectContext,
                             _ predicate: NSPredicate? = nil,
                             _ sortDescriptors: [NSSortDescriptor]? = nil) -> Document? {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()

        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = sortDescriptors

        do {
            let fetchedDocument = try context.fetch(fetchRequest)
            return fetchedDocument.first
        } catch {
            Logger.shared.logError("Error fetching note: \(error.localizedDescription)", category: .coredata)
        }

        return nil
    }

    class func fetchAll(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil) -> [Document] {
        return fetchAllWithLimit(context: context, predicate, sortDescriptors)
    }

    class func rawFetchAll(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil) -> [Document] {
        return rawFetchAllWithLimit(context: context, predicate, sortDescriptors)
    }

    class func fetchAllWithLimit(context: NSManagedObjectContext,
                                 _ predicate: NSPredicate? = nil,
                                 _ sortDescriptors: [NSSortDescriptor]? = nil,
                                 _ limit: Int = 0,
                                 _ fetchOffset: Int = 0) -> [Document] {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = processPredicate(predicate, DatabaseManager.defaultDatabase.id, onlyNonDeleted: true)
        fetchRequest.fetchLimit = limit
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchOffset = fetchOffset

        do {
            let fetchedDocuments = try context.fetch(fetchRequest)
            return fetchedDocuments
        } catch {
            // TODO: raise error?
            Logger.shared.logError("Can't fetch all: \(error)", category: .coredata)
        }

        return []
    }

    class func rawFetchAllWithLimit(context: NSManagedObjectContext,
                                    _ predicate: NSPredicate? = nil,
                                    _ sortDescriptors: [NSSortDescriptor]? = nil,
                                    _ limit: Int = 0,
                                    _ fetchOffset: Int = 0) -> [Document] {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = limit
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchOffset = fetchOffset

        do {
            let fetchedDocuments = try context.fetch(fetchRequest)
            return fetchedDocuments
        } catch {
            // TODO: raise error?
            Logger.shared.logError("Can't fetch: \(error)", category: .coredata)
        }

        return []
    }

    class func fetchAllNames(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil) -> [String] {
        return fetchAllNamesWithLimit(context: context, predicate, sortDescriptors)
    }

    class func fetchAllNamesWithLimit(context: NSManagedObjectContext,
                                      _ predicate: NSPredicate? = nil,
                                      _ sortDescriptors: [NSSortDescriptor]? = nil,
                                      _ limit: Int = 0) -> [String] {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = processPredicate(predicate, DatabaseManager.defaultDatabase.id, onlyNonDeleted: true)
        fetchRequest.fetchLimit = limit
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.propertiesToFetch = ["title"]

        do {
            let fetchedDocuments = try context.fetch(fetchRequest)
            return fetchedDocuments.compactMap { $0.title }
        } catch {
            // TODO: raise error?
            Logger.shared.logError("Can't fetch all: \(error)", category: .coredata)
        }

        return []
    }

    class func fetchWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Document? {
        return fetchFirst(context: context, NSPredicate(format: "id = %@", id as CVarArg),
                          onlyNonDeleted: false,
                          onlyDefaultDatabase: false)
    }

    class func fetchOrCreateWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Document {
        let document = fetchFirst(context: context, NSPredicate(format: "id = %@", id as CVarArg)) ?? create(context)
        document.id = id
        return document
    }

    class func rawFetchOrCreateWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Document {
        let document = rawFetchFirst(context: context, NSPredicate(format: "id = %@", id as CVarArg)) ?? create(context)
        document.id = id
        return document
    }

    class func fetchWithTitle(_ context: NSManagedObjectContext, _ title: String) -> Document? {
        return fetchFirst(context: context, NSPredicate(format: "title LIKE[cd] %@", title as CVarArg))
    }

    class func fetchOrCreateWithTitle(_ context: NSManagedObjectContext, _ title: String) -> Document {
        return fetchFirst(context: context, NSPredicate(format: "title LIKE[cd] %@", title as CVarArg)) ?? create(context, title: title)
    }

    class func fetchAllWithType(_ context: NSManagedObjectContext, _ type: Int16) -> [Document] {
        return fetchAll(context: context, NSPredicate(format: "document_type = \(type)"))
    }

    class func fetchWithTypeAndLimit(context: NSManagedObjectContext, _ type: Int16, _ limit: Int, _ fetchOffset: Int) -> [Document] {
        return fetchAllWithLimit(context: context, NSPredicate(format: "document_type = \(type)"), [NSSortDescriptor(key: "created_at", ascending: false)], limit, fetchOffset)
    }

    class func fetchAllWithTitleMatch(_ context: NSManagedObjectContext, _ title: String) -> [Document] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", title as CVarArg)
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
        return fetchAll(context: context, predicate, [sortDescriptor])
    }

    class func fetchAllWithLimitedTitleMatch(_ context: NSManagedObjectContext, _ title: String, _ limit: Int) -> [Document] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", title as CVarArg)
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
        return fetchAllWithLimit(context: context, predicate, [sortDescriptor], limit)
    }

    class func fetchAllWithLimitResult(_ context: NSManagedObjectContext, _ limit: Int, _ sortDescriptors: [NSSortDescriptor]? = nil) -> [Document] {
        return fetchAllWithLimit(context: context, nil, sortDescriptors, limit)
    }

    /// Will add the following predicates:
    /// - Add filter to only list non-deleted notes
    /// - Add filter to list only the default database
    class func processPredicate(_ predicate: NSPredicate? = nil,
                                _ databaseId: UUID? = nil,
                                onlyNonDeleted: Bool = true) -> NSPredicate {
        var predicates: [NSPredicate] = []

        if onlyNonDeleted {
            predicates.append(NSPredicate(format: "deleted_at == nil"))
        }

        if let databaseId = databaseId {
            predicates.append(NSPredicate(format: "database_id = %@",
                                          databaseId as CVarArg))
        }

        if let predicate = predicate {
            predicates.append(predicate)
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    // MARK: -
    // MARK: Validations
    override func validateForInsert() throws {
        try super.validateForInsert()
    }

    override func validateForDelete() throws {
        try super.validateForDelete()
    }

    override func validateForUpdate() throws {
        try super.validateForUpdate()
    }
}
