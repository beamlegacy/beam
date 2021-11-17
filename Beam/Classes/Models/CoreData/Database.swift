import Foundation
import CoreData
import BeamCore

class Database: NSManagedObject, BeamCoreDataObject {
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
        "\(title) {\(id)}"
    }

    func update(_ databaseStruct: DatabaseStruct) {
        title = databaseStruct.title
        created_at = databaseStruct.createdAt
        updated_at = databaseStruct.updatedAt
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
        DocumentManager().count(filters: [.databaseId(id)])
    }

    class func defaultDatabase(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext) -> Database {
        (try? Database.fetchWithId(context, DatabaseManager.defaultDatabase.id)) ?? Database.fetchOrCreateWithTitle(context, "Default")
    }

    class func deleteWithPredicate(_ context: NSManagedObjectContext,
                                   _ predicate: NSPredicate? = nil) throws {
        try context.performAndWait {
            for database in try Database.rawFetchAllWithLimit(context, predicate) {
                context.delete(database)
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

    class func create(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext,
                      title: String? = nil) -> Database {
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
            result = try fetchFirst(context, NSPredicate(format: "title = %@", title as CVarArg))
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }

        return result ?? create(context, title: title)
    }

    class func fetchAllWithLimit(_ context: NSManagedObjectContext,
                                 _ predicate: NSPredicate? = nil,
                                 _ sortDescriptors: [NSSortDescriptor]? = nil,
                                 _ limit: Int = 0,
                                 _ fetchOffset: Int = 0) throws -> [Database] {
        try fetchAllWithLimit(context,
                              predicate,
                              sortDescriptors,
                              limit,
                              fetchOffset,
                              onlyNonDeleted: true)
    }

    class func rawFetchAllWithLimit(_ context: NSManagedObjectContext,
                                    _ predicate: NSPredicate? = nil,
                                    _ sortDescriptors: [NSSortDescriptor]? = nil,
                                    _ limit: Int = 0,
                                    _ fetchOffset: Int = 0) throws -> [Database] {
        try fetchAllWithLimit(context,
                              predicate,
                              sortDescriptors,
                              limit,
                              fetchOffset,
                              onlyNonDeleted: false)
    }

    class private func fetchAllWithLimit(_ context: NSManagedObjectContext,
                                         _ predicate: NSPredicate?,
                                         _ sortDescriptors: [NSSortDescriptor]?,
                                         _ limit: Int,
                                         _ fetchOffset: Int,
                                         onlyNonDeleted: Bool) throws -> [Database] {
        let fetchRequest: NSFetchRequest<Database> = Database.fetchRequest()
        fetchRequest.predicate = processPredicate(predicate, onlyNonDeleted: onlyNonDeleted)
        fetchRequest.fetchLimit = limit
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchOffset = fetchOffset

        return try context.fetch(fetchRequest)
    }

    static func rawFetchAll(_ context: NSManagedObjectContext,
                            _ predicate: NSPredicate? = nil,
                            _ sortDescriptors: [NSSortDescriptor]? = nil) throws -> [Database] {
        try rawFetchAllWithLimit(context, predicate, sortDescriptors)
    }

    class func countWithPredicate(_ context: NSManagedObjectContext,
                                  _ predicate: NSPredicate? = nil) -> Int {
        rawCountWithPredicate(context, predicate, onlyNonDeleted: true)
    }

    static func rawCountWithPredicate(_ context: NSManagedObjectContext,
                                      _ predicate: NSPredicate? = nil) -> Int {
        rawCountWithPredicate(context, predicate, onlyNonDeleted: false)
    }

    static private func rawCountWithPredicate(_ context: NSManagedObjectContext,
                                              _ predicate: NSPredicate?,
                                              onlyNonDeleted: Bool) -> Int {
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

    class func fetchAllWithIds(_ context: NSManagedObjectContext, _ ids: [UUID]) throws -> [Database] {
        try rawFetchAll(context, NSPredicate(format: "id IN %@", ids))
    }

    class func fetchWithId(_ context: NSManagedObjectContext, _ id: UUID) throws -> Database? {
        return try rawFetchFirst(context,
                                 NSPredicate(format: "id = %@", id as CVarArg))
    }

    class func fetchOrCreateWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Database {
        rawFetchOrCreateWithId(context, id)
    }

    class func rawFetchOrCreateWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Database {
        let database = (try? rawFetchFirst(context, NSPredicate(format: "id = %@", id as CVarArg))) ?? create(context)
        database.id = id
        return database
    }

    static func fetchFirst(_ context: NSManagedObjectContext,
                           _ predicate: NSPredicate? = nil,
                           _ sortDescriptors: [NSSortDescriptor]? = nil) throws -> Database? {
        try fetchFirst(context, predicate, sortDescriptors, onlyNonDeleted: true)
    }

    class func rawFetchFirst(_ context: NSManagedObjectContext,
                             _ predicate: NSPredicate? = nil,
                             _ sortDescriptors: [NSSortDescriptor]? = nil) throws -> Database? {
        try fetchFirst(context, predicate, sortDescriptors, onlyNonDeleted: false)
    }

    class private func fetchFirst(_ context: NSManagedObjectContext,
                                  _ predicate: NSPredicate? = nil,
                                  _ sortDescriptors: [NSSortDescriptor]? = nil,
                                  onlyNonDeleted: Bool) throws -> Database? {
        let fetchRequest: NSFetchRequest<Database> = Database.fetchRequest()
        fetchRequest.predicate = processPredicate(predicate, onlyNonDeleted: onlyNonDeleted)
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = sortDescriptors

        let fetchedDatabase = try context.fetch(fetchRequest)
        return fetchedDatabase.first
    }

    class func fetchAll(_ context: NSManagedObjectContext,
                        _ predicate: NSPredicate? = nil,
                        _ sortDescriptors: [NSSortDescriptor]? = nil) throws -> [Database] {
        try fetchAllWithLimit(context, predicate, sortDescriptors)
    }

    /// Will add the following predicates:
    /// - Add filter to only list non-deleted notes
    /// - Add filter to list only the default database
    class private func processPredicate(_ predicate: NSPredicate? = nil,
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
