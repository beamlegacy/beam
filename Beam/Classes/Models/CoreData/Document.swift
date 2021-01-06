import Foundation
import CoreData
import Down

class Document: NSManagedObject {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        created_at = Date()
        updated_at = Date()
        id = UUID()
    }

    var uuidString: String {
        id.uuidString.lowercased()
    }

    func asApiType() -> DocumentAPIType {
        let result = DocumentAPIType(document: self)
        return result
    }

    override func willSave() {
        if updated_at.timeIntervalSince(Date()) > 2.0 {
            self.updated_at = Date()
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

    class func countWithPredicate(_ context: NSManagedObjectContext, _ predicate: NSPredicate? = nil) -> Int {
        // Fetch existing if any
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = predicate

        do {
            let fetchedTransactions = try context.count(for: fetchRequest)
            return fetchedTransactions
        } catch {
            // TODO: raise error?
            Logger.shared.logError("Can't count: \(error)", category: .coredata)
        }

        return 0
    }

    class func fetchFirst(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil) -> Document? {
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

    class func fetchAllWithLimit(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil, _ limit: Int? = nil) -> [Document] {
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = limit ?? 0
        fetchRequest.sortDescriptors = sortDescriptors

        do {
            let fetchedDocuments = try context.fetch(fetchRequest)
            return fetchedDocuments
        } catch {
            // TODO: raise error?
            Logger.shared.logError("Can't fetch all: \(error)", category: .coredata)
        }

        return []
    }

    class func fetchWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Document? {
        return fetchFirst(context: context, NSPredicate(format: "id = %@", id as CVarArg))
    }

    class func fetchWithTitle(_ context: NSManagedObjectContext, _ title: String) -> Document? {
        return fetchFirst(context: context, NSPredicate(format: "title = %@", title as CVarArg))
    }

    class func fetchAllWithType(_ context: NSManagedObjectContext, _ type: Int16) -> [Document] {
        return fetchAll(context: context, NSPredicate(format: "documentType = %@", type as CVarArg))
    }

    class func fetchAllWithTitleMatch(_ context: NSManagedObjectContext, _ title: String) -> [Document] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", title as CVarArg)
        return fetchAll(context: context, predicate)
    }

    class func fetchAllWithLimitResult(_ context: NSManagedObjectContext, _ title: String, _ limit: Int) -> [Document] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", title as CVarArg)
        return fetchAllWithLimit(context: context, predicate, nil, limit)
    }

}
