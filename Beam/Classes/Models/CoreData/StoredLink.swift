//
//  Link.swift
//  Beam
//
//  Created by Sebastien Metrot on 19/01/2021.
//

import Foundation
import CoreData
import BeamCore

class StoredLink: NSManagedObject {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        bid = Int64(bitPattern: BID64().id)
    }

    override var debugDescription: String {
        return "\(id) [\(url)] \(title ?? "???")"
    }

    func delete(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext) {
        context.delete(self)
        do {
            try context.save()
        } catch {
            // TODO: raise error?
        }
    }

    // MARK: - CoreData Helpers
    class func countWithPredicate(_ context: NSManagedObjectContext, _ predicate: NSPredicate? = nil) -> Int {
        // Fetch existing if any
        let fetchRequest: NSFetchRequest<StoredLink> = StoredLink.fetchRequest()
        fetchRequest.predicate = predicate

        do {
            let fetchedTransactions = try context.count(for: fetchRequest)
            return fetchedTransactions
        } catch {
            // TODO: raise error?
        }

        return 0
    }

    class func fetchFirst(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil) -> StoredLink? {
        let fetchRequest: NSFetchRequest<StoredLink> = StoredLink.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = sortDescriptors

        do {
            let fetchedNote = try context.fetch(fetchRequest)
            return fetchedNote.first
        } catch {
            // TODO: raise error?
        }

        return nil
    }

    class func fetchWithId(_ context: NSManagedObjectContext, _ bid: Int64) -> StoredLink? {
        let predicate = NSPredicate(format: "bid = \(bid)")
        return fetchFirst(context: context, predicate)
    }

    class func fetchWithTitle(_ context: NSManagedObjectContext, _ title: String) -> StoredLink? {
        return fetchFirst(context: context, NSPredicate(format: "title = %@", title as CVarArg))
    }

    class func fetchWithUrl(_ context: NSManagedObjectContext, _ url: String) -> StoredLink? {
        return fetchFirst(context: context, NSPredicate(format: "url = %@", url as CVarArg))
    }

    class func fetchAllWithTitleMatch(_ context: NSManagedObjectContext, _ title: String) -> [StoredLink] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", title as CVarArg)
        return fetchAll(context: context, predicate)
    }

    class func fetchAll(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil) -> [StoredLink] {
        return fetchAllWithLimit(context: context, predicate, sortDescriptors)
    }

    class func fetchAllWithLimit(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil, _ limit: Int? = nil) -> [StoredLink] {
        let fetchRequest: NSFetchRequest<StoredLink> = StoredLink.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = limit ?? 0
        fetchRequest.sortDescriptors = sortDescriptors

        do {
            let fetchedLinks = try context.fetch(fetchRequest)
            return fetchedLinks
        } catch {
            // TODO: raise error?
            Logger.shared.logError("Can't fetch all: \(error)", category: .coredata)
        }

        return []
    }

    class func fetchAllWithLimitResult(_ context: NSManagedObjectContext, _ limit: Int) -> [StoredLink] {
        return fetchAllWithLimit(context: context, nil, nil, limit)
    }

    class func fetchAllWithPredicate(_ context: NSManagedObjectContext, _ predicate: NSPredicate? = nil) -> [StoredLink] {
        let fetchRequest: NSFetchRequest<StoredLink> = StoredLink.fetchRequest()
        fetchRequest.predicate = predicate

        do {
            let fetchedStoredLinks = try context.fetch(fetchRequest)
            return fetchedStoredLinks
        } catch {
            // TODO: raise error?
        }

        return []
    }

    class func deleteForPredicate(_ predicate: NSPredicate, _ context: NSManagedObjectContext) -> NSPersistentStoreResult? {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "StoredLink")
        fetch.predicate = predicate
        fetch.includesSubentities = false
        fetch.includesPropertyValues = false

        let request = NSBatchDeleteRequest(fetchRequest: fetch)
        request.resultType = .resultTypeObjectIDs
        do {
            #if DEBUG
            let count = try context.count(for: fetch)
            if count > 0 {
                NSLog("Deleted \(count) StoredLinks")
            }
            #endif
            let result = try context.execute(request) as? NSBatchDeleteResult

            // To propagate changes
            let objectIDArray = result?.result as? [NSManagedObjectID]
            let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDArray as Any]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context, CoreDataManager.shared.mainContext])

            return result
        } catch {
            // TODO: raise error?
            return nil
        }
    }
}

extension StoredLink {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StoredLink> {
        return NSFetchRequest<StoredLink>(entityName: "StoredLink")
    }

    @NSManaged public var bid: Int64
    @NSManaged public var url: String
    @NSManaged public var title: String?

}

extension StoredLink: Identifiable {

}
