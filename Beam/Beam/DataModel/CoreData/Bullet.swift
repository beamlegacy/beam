import Foundation
import CoreData

class Bullet: NSManagedObject {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        created_at = Date()
        updated_at = Date()
        id = UUID()
    }

    func parsedContent(_ parsedInternalLink: Bool = false) -> String {
        return parsedInternalLink ? BeamTextFormatter.parseForInternalLinks(content) : content
    }

    func internalLink() -> String {
        Self.internalLink(id)
    }

    class func internalLink(_ id: UUID) -> String {
        var components = Note.components()
        components.path = "/bullet"
        components.queryItems = [ URLQueryItem(name: "id", value: id.uuidString) ]

        return components.url?.absoluteString ?? "beam://"
    }

    func debugBullet(_ tabCount: Int = 0) {
        for _ in 0...tabCount {
            print("\t", terminator: "")
        }

        print("[\(orderIndex)] \(content)")

        for bullet in sortedChildren() {
            bullet.debugBullet(tabCount + 1)
        }
    }

    func sortedChildren() -> [Bullet] {
        guard let children = children else { return [] }

        let results = Array(children)

        return results.sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    override var debugDescription: String {
        return content
    }

    func treeBullets(_ tabCount: Int = 0) -> [Any]? {
        guard let children = children, children.count > 0 else {
            return [self]
        }

        let results: [Any] = [self, sortedChildren().compactMap { $0.treeBullets(tabCount + 1) }]

        return results
    }

    class func maxOrderIndex(_ context: NSManagedObjectContext, _ parentBullet: Bullet? = nil, note: Note) -> Int32 {
        // TODO: optimize speed
        var predicate = NSPredicate(format: "parent = nil AND note = %@", note)

        if let parentBullet = parentBullet {
            predicate = NSPredicate(format: "parent = %@ AND note = %@", parentBullet, note)
        }

        let orderIndex = Bullet.fetchAllWithPredicate(context, predicate)
            .sorted(by: { $0.orderIndex < $1.orderIndex }).last?.orderIndex

        return orderIndex ?? 0
    }

    // MARK: - CoreData Helpers
    class func countWithPredicate(_ context: NSManagedObjectContext, _ predicate: NSPredicate? = nil) -> Int {
        // Fetch existing if any
        let fetchRequest: NSFetchRequest<Bullet> = Bullet.fetchRequest()
        fetchRequest.predicate = predicate

        do {
            let fetchedTransactions = try context.count(for: fetchRequest)
            return fetchedTransactions
        } catch {
            // TODO: raise error?
        }

        return 0
    }

    class func fetchFirst(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil) -> Bullet? {
        let fetchRequest: NSFetchRequest<Bullet> = Bullet.fetchRequest()
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

    class func fetchWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Bullet? {
        return fetchFirst(context: context, NSPredicate(format: "id = %@", id as CVarArg))
    }

    class func fetchAllWithPredicate(_ context: NSManagedObjectContext, _ predicate: NSPredicate? = nil) -> [Bullet] {
        let fetchRequest: NSFetchRequest<Bullet> = Bullet.fetchRequest()
        fetchRequest.predicate = predicate

        do {
            let fetchedBullets = try context.fetch(fetchRequest)
            return fetchedBullets
        } catch {
            // TODO: raise error?
        }

        return []
    }

    func delete(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext) {
        context.delete(self)
        do {
            try context.save()
        } catch {
            // TODO: raise error?
        }
    }

    class func deleteForPredicate(_ predicate: NSPredicate, _ context: NSManagedObjectContext) -> NSPersistentStoreResult? {
        let fetch: NSFetchRequest<Bullet> = Bullet.fetchRequest()
        fetch.predicate = predicate
        fetch.includesSubentities = false
        fetch.includesPropertyValues = false

        let request = NSBatchDeleteRequest(fetchRequest: fetch)
        request.resultType = .resultTypeObjectIDs
        do {
            #if DEBUG
            let count = try context.count(for: fetch)
            if count > 0 {
                NSLog("Deleted \(count) bullets")
            }
            #endif
            let result = try context.execute(request) as? NSBatchDeleteResult

            // To propagate changes
            let objectIDArray = result?.result as? [NSManagedObjectID]
            let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDArray as Any]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context, CoreDataManager.shared.managedContext])

            return result
        } catch {
            // TODO: raise error?
            return nil
        }
    }
}
