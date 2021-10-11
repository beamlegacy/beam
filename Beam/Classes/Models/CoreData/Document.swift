// swiftlint:disable file_length
import Foundation
import CoreData
import BeamCore

class Document: NSManagedObject, BeamCoreDataObject {
    /*
     Updating `updated_at` in `override func willSave()` raises an issue: when we receive objects from API with
     `receivedObjects` it will overwrite `updated_at` but we don't want to, as it will keep updating it
     for every remote updates we get. We want the local object to represent exactly what we fetched.

     Instead we should update `updated_at` manually when doing changes (on save).
     */

    override func awakeFromInsert() {
        super.awakeFromInsert()
        created_at = BeamDate.now
        updated_at = BeamDate.now
        id = UUID()
    }

    var uuidString: String {
        id.uuidString.lowercased()
    }

    var titleAndId: String {
        "\(title) {\(id)} v\(version)"
    }

    var hasLocalChanges: Bool {
        // We don't have a saved previous version, it's a new document
        guard let beam_api_data = beam_api_data else { return false }

        return beam_api_data != data
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
        try? Database.fetchWithId(context, database_id)
    }

    /// Slower than `deleteBatchWithPredicate` but I can't get `deleteBatchWithPredicate`
    /// to properly propagate changes to other contexts :(
    class func deleteWithPredicate(_ context: NSManagedObjectContext, _ predicate: NSPredicate? = nil) throws {
        try context.performAndWait {
            for document in try Document.rawFetchAllWithLimit(context, predicate) {
                context.delete(document)
            }
        }

        do {
            try context.save()
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }
    }

    class func deleteBatchWithPredicate(_ context: NSManagedObjectContext,
                                        _ predicate: NSPredicate? = nil) throws {
        let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Document")
        deleteFetch.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)

        deleteRequest.resultType = .resultTypeObjectIDs

        try context.performAndWait {
            for document in try Document.rawFetchAllWithLimit(context) {
                Logger.shared.logDebug("title: \(document.title) database_id: \(document.database_id)",
                                       category: .documentDebug)
            }

            Logger.shared.logDebug("About to delete \(rawCountWithPredicate(context, predicate)) documents",
                                   category: .document)

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
        document.document_type = DocumentType.note.rawValue
        if let title = title {
            document.title = title
        }

        return document
    }

    func update(_ documentStruct: DocumentStruct) {
        database_id = documentStruct.databaseId
        // use mergeWithLocalChanges for `data`
        // data = documentStruct.data
        title = documentStruct.title
        document_type = documentStruct.documentType.rawValue
        created_at = documentStruct.createdAt
        updated_at = BeamDate.now
        deleted_at = documentStruct.deletedAt
        is_public = documentStruct.isPublic

        if let journalDate = documentStruct.journalDate, !journalDate.isEmpty {
            journal_day = JournalDateConverter.toInt(from: journalDate)
        }
    }

    class func countWithPredicate(_ context: NSManagedObjectContext,
                                  _ predicate: NSPredicate? = nil) -> Int {
        countWithPredicate(context,
                           predicate,
                           DatabaseManager.defaultDatabase.id,
                           onlyNonDeleted: true)
    }

    class func countWithPredicate(_ context: NSManagedObjectContext,
                                  _ predicate: NSPredicate? = nil,
                                  _ databaseId: UUID? = nil) -> Int {
        countWithPredicate(context,
                           predicate,
                           databaseId ?? DatabaseManager.defaultDatabase.id,
                           onlyNonDeleted: true)
    }

    class func rawCountWithPredicate(_ context: NSManagedObjectContext,
                                     _ predicate: NSPredicate? = nil) -> Int {
        countWithPredicate(context, predicate, nil, onlyNonDeleted: false)
    }

    class private func countWithPredicate(_ context: NSManagedObjectContext,
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

    class func fetchFirst(_ context: NSManagedObjectContext,
                          _ predicate: NSPredicate? = nil,
                          _ sortDescriptors: [NSSortDescriptor]? = nil) throws -> Document? {
        try fetchFirst(context,
                       predicate,
                       sortDescriptors,
                       onlyNonDeleted: true,
                       onlyDefaultDatabase: true)
    }

    class func rawFetchFirst(_ context: NSManagedObjectContext,
                             _ predicate: NSPredicate? = nil,
                             _ sortDescriptors: [NSSortDescriptor]? = nil) throws -> Document? {
        try fetchFirst(context,
                       predicate,
                       sortDescriptors,
                       onlyNonDeleted: false,
                       onlyDefaultDatabase: false)
    }

    class private func fetchFirst(_ context: NSManagedObjectContext,
                                  _ predicate: NSPredicate? = nil,
                                  _ sortDescriptors: [NSSortDescriptor]? = nil,
                                  onlyNonDeleted: Bool,
                                  onlyDefaultDatabase: Bool) throws -> Document? {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()

        fetchRequest.predicate = processPredicate(predicate,
                                                  onlyDefaultDatabase ? DatabaseManager.defaultDatabase.id : nil,
                                                  onlyNonDeleted: onlyNonDeleted)
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = sortDescriptors

        let fetchedDocument = try context.fetch(fetchRequest)
        return fetchedDocument.first
    }

    class func fetchAll(_ context: NSManagedObjectContext,
                        _ predicate: NSPredicate? = nil,
                        _ sortDescriptors: [NSSortDescriptor]? = nil) throws -> [Document] {
        try fetchAllWithLimit(context, predicate, sortDescriptors, 0, 0)
    }

    class func fetchAll(_ context: NSManagedObjectContext,
                        _ predicate: NSPredicate? = nil,
                        _ sortDescriptors: [NSSortDescriptor]? = nil,
                        _ databaseId: UUID? = DatabaseManager.defaultDatabase.id) throws -> [Document] {
        try fetchAllWithLimit(context, predicate, sortDescriptors, 0, 0, databaseId)
    }

    class func rawFetchAll(_ context: NSManagedObjectContext,
                           _ predicate: NSPredicate? = nil,
                           _ sortDescriptors: [NSSortDescriptor]? = nil) throws -> [Document] {
        try rawFetchAllWithLimit(context, predicate, sortDescriptors)
    }

    class func fetchAllWithLimit(_ context: NSManagedObjectContext,
                                 _ predicate: NSPredicate? = nil,
                                 _ sortDescriptors: [NSSortDescriptor]? = nil,
                                 _ limit: Int = 0,
                                 _ fetchOffset: Int = 0) throws -> [Document] {
        try fetchAllWithLimit(context, predicate, sortDescriptors, limit, fetchOffset, DatabaseManager.defaultDatabase.id)
    }

    class func fetchAllWithLimit(_ context: NSManagedObjectContext,
                                 _ predicate: NSPredicate? = nil,
                                 _ sortDescriptors: [NSSortDescriptor]? = nil,
                                 _ limit: Int = 0,
                                 _ fetchOffset: Int = 0,
                                 _ databaseId: UUID? = DatabaseManager.defaultDatabase.id) throws -> [Document] {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = processPredicate(predicate,
                                                  databaseId,
                                                  onlyNonDeleted: true)
        fetchRequest.fetchLimit = limit
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchOffset = fetchOffset

        let fetchedDocuments = try context.fetch(fetchRequest)
        return fetchedDocuments
    }

    class func rawFetchAllWithLimit(_ context: NSManagedObjectContext,
                                    _ predicate: NSPredicate? = nil,
                                    _ sortDescriptors: [NSSortDescriptor]? = nil,
                                    _ limit: Int = 0,
                                    _ fetchOffset: Int = 0) throws -> [Document] {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = limit
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchOffset = fetchOffset

        let fetchedDocuments = try context.fetch(fetchRequest)
        return fetchedDocuments
    }

    class func fetchAllNames(_ context: NSManagedObjectContext,
                             _ predicate: NSPredicate? = nil,
                             _ sortDescriptors: [NSSortDescriptor]? = nil) -> [String] {
        return fetchAllNamesWithLimit(context, predicate, sortDescriptors)
    }

    class func fetchAllNamesWithLimit(_ context: NSManagedObjectContext,
                                      _ predicate: NSPredicate? = nil,
                                      _ sortDescriptors: [NSSortDescriptor]? = nil,
                                      _ limit: Int = 0) -> [String] {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = processPredicate(predicate,
                                                  DatabaseManager.defaultDatabase.id,
                                                  onlyNonDeleted: true)
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

    class func fetchAllWithIds(_ context: NSManagedObjectContext, _ ids: [UUID]) throws -> [Document] {
        try rawFetchAll(context, NSPredicate(format: "id IN %@", ids))
    }

    class func fetchWithId(_ context: NSManagedObjectContext, _ id: UUID) throws -> Document? {
        try rawFetchFirst(context, NSPredicate(format: "id = %@", id as CVarArg))
    }

    class func fetchOrCreateWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Document {
        rawFetchOrCreateWithId(context, id)
    }

    class func rawFetchOrCreateWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Document {
        let document = (try? fetchWithId(context, id)) ?? create(context)
        document.id = id
        return document
    }

    class func fetchWithTitle(_ context: NSManagedObjectContext, _ title: String) throws -> Document? {
        try fetchFirst(context, NSPredicate(format: "title ==[cd] %@", title as CVarArg))
    }

    class func fetchOrCreateWithTitle(_ context: NSManagedObjectContext, _ title: String) -> Document {
        (try? fetchFirst(context, NSPredicate(format: "title ==[cd] %@", title as CVarArg)))
            ?? create(context, title: title)
    }

    class func fetchWithJournalDate(_ context: NSManagedObjectContext, _ date: String) -> Document? {
        let date = JournalDateConverter.toInt(from: date)
        return try? fetchFirst(context, NSPredicate(format: "journal_day == \(date)"))
    }

    class func fetchAllWithType(_ context: NSManagedObjectContext, _ type: Int16) throws -> [Document] {
        try fetchAll(context, NSPredicate(format: "document_type = \(type)"))
    }

    class func fetchWithTypeAndLimit(context: NSManagedObjectContext,
                                     _ type: Int16,
                                     _ limit: Int,
                                     _ fetchOffset: Int) throws -> [Document] {

        let today = BeamNoteType.titleForDate(BeamDate.now)
        let todayInt = JournalDateConverter.toInt(from: today)

        return try fetchAllWithLimit(context,
                              NSPredicate(format: "document_type = \(type) AND journal_day <= \(todayInt)"),
                              [NSSortDescriptor(key: "journal_day", ascending: false),
                              NSSortDescriptor(key: "created_at", ascending: false)],
                              limit,
                              fetchOffset)
    }

    class func fetchAllWithTitleMatch(_ context: NSManagedObjectContext, _ title: String) throws -> [Document] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", title as CVarArg)
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: true, selector: #selector(NSString.caseInsensitiveCompare))
        return try fetchAll(context, predicate, [sortDescriptor])
    }

    class func fetchAllWithLimitedTitleMatch(_ context: NSManagedObjectContext,
                                             _ title: String,
                                             _ limit: Int) throws -> [Document] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", title as CVarArg)
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: true, selector: #selector(NSString.caseInsensitiveCompare))
        return try fetchAllWithLimit(context, predicate, [sortDescriptor], limit)
    }

    class func fetchAllWithLimitResult(_ context: NSManagedObjectContext,
                                       _ limit: Int,
                                       _ sortDescriptors: [NSSortDescriptor]? = nil) throws -> [Document] {
        try fetchAllWithLimit(context, nil, sortDescriptors, limit)
    }

    /// Will add the following predicates:
    /// - Add filter to only list non-deleted notes
    /// - Add filter to list only the default database
    class private func processPredicate(_ predicate: NSPredicate? = nil,
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
