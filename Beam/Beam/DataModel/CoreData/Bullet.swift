import Foundation
import CoreData

class Bullet: NSManagedObject {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        created_at = Date()
        updated_at = Date()
        id = UUID()
    }

    func debugBullet(_ tabCount: Int = 0) {
        for _ in 0...tabCount {
            print("\t", terminator: "")
        }

        print("[\(orderIndex)] \(content ?? "-")")

        for bullet in sortedChildren() {
            bullet.debugBullet(tabCount + 1)
        }
    }

    func sortedChildren() -> [Bullet] {
        guard let children = children else { return [] }

        let results = Array(children).compactMap { $0 as? Bullet }

        return results.sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    override var debugDescription: String {
        return content ?? "No title"
    }

    func detectLinkedNotes(_ context: NSManagedObjectContext) {
        guard let content = content, content.count > 2 else { return }

        let patterns: [String] = ["\\[\\[(.+?)\\]\\]", "\\#([^\\#]+)"]

        for pattern in patterns {
            var regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [])
            } catch {
                // TODO: manage errors
                fatalError("Error")
            }

            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))

            for match in matches {
                guard let linkRange = Range(match.range(at: 1), in: content) else { continue }

                let linkTitle = String(content[linkRange])
                let note = Note.createNote(context, linkTitle)
                note.addToLinkedReferences(self)
            }
        }
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

    class func fetchAll(_ context: NSManagedObjectContext) -> [Bullet] {
        let fetchRequest: NSFetchRequest<Bullet> = Bullet.fetchRequest()

        do {
            let fetchedNotes = try context.fetch(fetchRequest)
            return fetchedNotes
        } catch {
            // TODO: raise error?
        }

        return []
    }
}
