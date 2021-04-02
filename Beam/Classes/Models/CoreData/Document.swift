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

    func asApiType() -> DocumentAPIType {
        let result = DocumentAPIType(document: self)
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

    class func create(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext, title: String? = nil) -> Document {
        let document = Document(context: context)
        document.id = UUID()
        document.version = 0
        if let title = title {
            document.title = title
        }

        return document
    }

    func update(_ documentStruct: DocumentStruct) {
        data = documentStruct.data
        title = documentStruct.title
        document_type = documentStruct.documentType.rawValue
        created_at = documentStruct.createdAt
        updated_at = BeamDate.now
        if documentStruct.documentType == .journal {
            do {
                let note = try JSONDecoder().decode(BeamNote.self, from: documentStruct.data)
                deleted_at = note.isEntireNoteEmpty() ? BeamDate.now : documentStruct.deletedAt
            } catch {
                Logger.shared.logError("Unable to decode journal's note", category: .document)
            }
        } else {
            deleted_at = documentStruct.deletedAt
        }
        is_public = documentStruct.isPublic
    }

    class func countWithPredicate(_ context: NSManagedObjectContext,
                                  _ predicate: NSPredicate? = nil) -> Int {
        return rawCountWithPredicate(context, predicate, onlyNonDeleted: true)
    }

    class func rawCountWithPredicate(_ context: NSManagedObjectContext,
                                     _ predicate: NSPredicate? = nil,
                                     onlyNonDeleted: Bool = false) -> Int {
        // Fetch existing if any
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()

        fetchRequest.predicate = onlyNonDeleted ? onlyNonDeletedPredicate(predicate) : predicate

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
                          onlyNonDeleted: Bool = true) -> Document? {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = onlyNonDeleted ? onlyNonDeletedPredicate(predicate) : predicate
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

    class func fetchAllWithLimit(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil, _ limit: Int = 0, _ fetchOffset: Int = 0) -> [Document] {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = onlyNonDeletedPredicate(predicate)
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

    class func fetchAllNames(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil) -> [String] {
        return fetchAllNamesWithLimit(context: context, predicate, sortDescriptors)
    }

    class func fetchAllNamesWithLimit(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil, _ limit: Int = 0) -> [String] {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = onlyNonDeletedPredicate(predicate)
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
        return fetchFirst(context: context, NSPredicate(format: "id = %@", id as CVarArg), onlyNonDeleted: false)
    }

    class func fetchOrCreateWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Document {
        let document = fetchFirst(context: context, NSPredicate(format: "id = %@", id as CVarArg)) ?? create(context)
        document.id = id
        return document
    }

    class func fetchWithTitle(_ context: NSManagedObjectContext, _ title: String) -> Document? {
        return fetchFirst(context: context, NSPredicate(format: "title = %@", title as CVarArg))
    }

    class func fetchOrCreateWithTitle(_ context: NSManagedObjectContext, _ title: String) -> Document {
        return fetchFirst(context: context, NSPredicate(format: "title = %@", title as CVarArg)) ?? create(context, title: title)
    }

    class func fetchAllWithType(_ context: NSManagedObjectContext, _ type: Int16) -> [Document] {
        return fetchAll(context: context, NSPredicate(format: "document_type = \(type)"))
    }

    class func fetchWithTypeAndLimit(context: NSManagedObjectContext, _ type: Int16, _ limit: Int, _ fetchOffset: Int) -> [Document] {
        return fetchAllWithLimit(context: context, NSPredicate(format: "document_type = \(type)"), [NSSortDescriptor(key: "created_at", ascending: false)], limit, fetchOffset)
    }

    class func fetchAllWithTitleMatch(_ context: NSManagedObjectContext, _ title: String) -> [Document] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", title as CVarArg)
        return fetchAll(context: context, predicate)
    }

    class func fetchAllWithLimitedTitleMatch(_ context: NSManagedObjectContext, _ title: String, _ limit: Int) -> [Document] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", title as CVarArg)
        return fetchAllWithLimit(context: context, predicate, nil, limit)
    }

    class func fetchAllWithLimitResult(_ context: NSManagedObjectContext, _ limit: Int, _ sortDescriptors: [NSSortDescriptor]? = nil) -> [Document] {
        return fetchAllWithLimit(context: context, nil, sortDescriptors, limit)
    }

    class func onlyNonDeletedPredicate(_ predicate: NSPredicate? = nil) -> NSPredicate {
        // We don't want deleted documents
        var fetchPredicate = NSPredicate(format: "deleted_at == nil")
        if let predicate = predicate {
            fetchPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fetchPredicate, predicate])
        }
        return fetchPredicate
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
