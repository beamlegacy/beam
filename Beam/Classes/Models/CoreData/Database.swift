import Foundation
import CoreData
import BeamCore

class Database: NSManagedObject {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        created_at = BeamDate.now
        updated_at = BeamDate.now
        id = UUID()
    }

    override func willSave() {
        let keys = self.changedValues().keys
        if updated_at.timeIntervalSince(BeamDate.now) < -1.0 {
            if keys.contains("title") {
                self.updated_at = BeamDate.now
            }
        }
        super.willSave()
    }

    var uuidString: String {
        id.uuidString.lowercased()
    }

    func asApiType() -> DatabaseAPIType {
        let result = DatabaseAPIType(database: self)
        return result
    }

    func update(_ databaseStruct: DatabaseStruct) {
        title = databaseStruct.title
        created_at = databaseStruct.createdAt
        deleted_at = databaseStruct.deletedAt
    }

    func delete(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext) {
        context.delete(self)
        do {
            try context.save()
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }
    }

    func documentsCount() -> Int {
        Document.countWithPredicate(CoreDataManager.shared.mainContext, NSPredicate(format: "deleted_at == nil"), id)
    }

    class func defaultDatabase(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext) -> Database {
        (try? Database.fetchWithId(context, DatabaseManager.defaultDatabase.id)) ?? Database.fetchOrCreateWithTitle(context, "Default")
    }

    class func deleteWithPredicate(_ context: NSManagedObjectContext, _ predicate: NSPredicate? = nil) throws {
        // TODO: we should fetch documents for the selected databases, and delete
        // them as well or move them to a default database?

        let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Database")
        deleteFetch.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)

        deleteRequest.resultType = .resultTypeObjectIDs

        try context.performAndWait {
            try context.execute(deleteRequest)

            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult

            // We don't need to propagate changes if already main context
            guard CoreDataManager.shared.mainContext != context else { return }

            // Note: this seems to be propagating the deletes to the main managedContext
            // even without this, but documentation says we should do it so...

            // Retrieves the IDs deleted
            guard let objectIDs = result?.result as? [NSManagedObjectID] else { return }

            // Updates the main context
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes,
                                                into: [CoreDataManager.shared.mainContext])
        }
    }

    class func create(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext, title: String? = nil) -> Database {
        let database = Database(context: context)
        database.id = UUID()
        if let title = title {
            database.title = title
        }

        return database
    }

    class func fetchOrCreateWithTitle(_ context: NSManagedObjectContext, _ title: String) -> Database {
        var result: Database?
        do {
            result = try fetchFirst(context: context, NSPredicate(format: "title = %@", title as CVarArg))
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }

        return result ?? create(context, title: title)
    }

    class func fetchAllWithLimit(context: NSManagedObjectContext,
                                 _ predicate: NSPredicate? = nil,
                                 _ sortDescriptors: [NSSortDescriptor]? = nil,
                                 _ limit: Int = 0,
                                 _ fetchOffset: Int = 0) throws -> [Database] {
        let fetchRequest: NSFetchRequest<Database> = Database.fetchRequest()
        fetchRequest.predicate = processPredicate(predicate, onlyNonDeleted: true)
        fetchRequest.fetchLimit = limit
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchOffset = fetchOffset

        return try context.fetch(fetchRequest)
    }

    class func countWithPredicate(_ context: NSManagedObjectContext,
                                  _ predicate: NSPredicate? = nil) -> Int {
        return rawCountWithPredicate(context, predicate, onlyNonDeleted: true)
    }

    class func rawCountWithPredicate(_ context: NSManagedObjectContext,
                                     _ predicate: NSPredicate? = nil,
                                     onlyNonDeleted: Bool = false) -> Int {
        // Fetch existing if any
        let fetchRequest: NSFetchRequest<Database> = Database.fetchRequest()

        fetchRequest.predicate = processPredicate(predicate, onlyNonDeleted: onlyNonDeleted)

        do {
            let fetchedTransactions = try context.count(for: fetchRequest)
            return fetchedTransactions
        } catch {
            // TODO: raise error?
            Logger.shared.logError("Can't count: \(error)", category: .coredata)
        }

        return 0
    }

    class func fetchWithId(_ context: NSManagedObjectContext, _ id: UUID) throws -> Database? {
        return try fetchFirst(context: context, NSPredicate(format: "id = %@", id as CVarArg), onlyNonDeleted: false)
    }

    class func rawFetchWithId(_ context: NSManagedObjectContext, _ id: UUID) throws -> Database? {
        return try rawFetchFirst(context: context, NSPredicate(format: "id = %@", id as CVarArg))
    }

    class func fetchOrCreateWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Database {
        let database = (try? fetchFirst(context: context, NSPredicate(format: "id = %@", id as CVarArg))) ?? create(context)
        database.id = id
        return database
    }

    class func fetchFirst(context: NSManagedObjectContext,
                          _ predicate: NSPredicate? = nil,
                          _ sortDescriptors: [NSSortDescriptor]? = nil,
                          onlyNonDeleted: Bool = true) throws -> Database? {
        let fetchRequest: NSFetchRequest<Database> = Database.fetchRequest()
        fetchRequest.predicate = processPredicate(predicate, onlyNonDeleted: onlyNonDeleted)
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = sortDescriptors

        let fetchedDatabase = try context.fetch(fetchRequest)
        return fetchedDatabase.first
    }

    class func rawFetchFirst(context: NSManagedObjectContext,
                             _ predicate: NSPredicate? = nil,
                             _ sortDescriptors: [NSSortDescriptor]? = nil) throws -> Database? {
        let fetchRequest: NSFetchRequest<Database> = Database.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = sortDescriptors

        let fetchedDatabase = try context.fetch(fetchRequest)
        return fetchedDatabase.first
    }

    class func fetchAll(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil) throws -> [Database] {
        try fetchAllWithLimit(context: context, predicate, sortDescriptors)
    }

    /// Will add the following predicates:
    /// - Add filter to only list non-deleted notes
    /// - Add filter to list only the default database
    class func processPredicate(_ predicate: NSPredicate? = nil,
                                onlyNonDeleted: Bool = true) -> NSPredicate {
        var predicates: [NSPredicate] = []

        if onlyNonDeleted {
            predicates.append(NSPredicate(format: "deleted_at == nil"))
        }

        if let predicate = predicate {
            predicates.append(predicate)
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
