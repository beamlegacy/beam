import Foundation
import CoreData

class Note: NSManagedObject {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        created_at = Date()
        updated_at = Date()
        id = UUID()
    }

    @discardableResult
    class func createNote(_ context: NSManagedObjectContext, _ title: String) -> Note {
        let existingNote = fetchWithTitle(context, title)

        let note = existingNote ?? Note(context: context)

        note.title = title

        return note
    }

    /// Will set the `orderIndex` properly, based on `afterBullet`
    /// - Parameters:
    ///   - context: <#context description#>
    ///   - content: <#content description#>
    ///   - afterBullet: <#afterBullet description#>
    /// - Returns: thre created `Bullet`
    func createBullet(_ context: NSManagedObjectContext, content: String, afterBullet: Bullet? = nil, parentBullet: Bullet? = nil) -> Bullet {
        let newBullet = Bullet(context:context)

        newBullet.content = content
        newBullet.note = self
        newBullet.parent = parentBullet ?? afterBullet?.parent

        let atIndex = afterBullet?.orderIndex ?? Bullet.maxOrderIndex(context, newBullet.parent, note: self)

        newBullet.orderIndex = atIndex + 1

        // Move all bullets lower
        if let bullets = bullets {
            // TODO: ugly, refactor
            for bullet in bullets where ((bullet as? Bullet)?.orderIndex ?? 0) > atIndex && ((bullet as? Bullet)?.id != newBullet.id) {
                guard let bullet = (bullet as? Bullet) else { continue }

                if bullet.parent == newBullet.parent {
                    bullet.orderIndex += 1
                }
            }
        }

        return newBullet
    }

    class func detectUnlinkedNotes(_ context: NSManagedObjectContext) {
        for note in Note.fetchAll(context: context) {
            note.detectUnlinkedNotes(context)
        }
    }

    func detectUnlinkedNotes(_ context: NSManagedObjectContext) {
        guard let title = title else { return }

        let predicate = NSPredicate(format: "content CONTAINS[cd] %@", title)

        for bullet in Bullet.fetchAllWithPredicate(context, predicate) {
            if linkedReferences?.contains(bullet) ?? false { continue }

            addToUnlinkedReferences(bullet)
        }
    }

    func debugNote() {
        print("> \(title ?? "Not note title")")

        let tree = treeBullets()

        displayBullets(tree)
        displayLinkedReferences()
        displayUnlinkedReferences()
        print("")
    }

    private func displayBullets(_ tree: [Any], _ tabCount: Int = 0) {
        for elements in tree {
            if let elements = elements as? [Any] {
                displayBullets(elements, tabCount + 1)
            } else if let element = elements as? Bullet {
                for _ in 0...tabCount {
                    print(" ", terminator: "")
                }
                print("[\(element.orderIndex)] \(element.content ?? "-")")
            } else {
                print("Not Found for \(elements)")
            }
        }
    }

    private func displayLinkedReferences() {
        guard let linkedReferences = linkedReferences, linkedReferences.count > 0 else { return }
        print("")
        print("  \(linkedReferences.count) Linked References")
        print("")

        displayReferences(linkedReferences)
    }

    private func displayUnlinkedReferences() {
        guard let unlinkedReferences = unlinkedReferences, unlinkedReferences.count > 0 else { return }
        print("")
        print("  \(unlinkedReferences.count) Unlinked References")
        print("")
        displayReferences(unlinkedReferences)
    }

    private func displayReferences(_ bullets: NSSet) {
        for bullet in bullets {
            guard let bullet = bullet as? Bullet else { continue }

            var currentBullet = bullet
            var bullets: [Bullet] = [currentBullet]
            while let parentBullet = currentBullet.parent {
                bullets.insert(parentBullet, at: 0)
                currentBullet = parentBullet
            }

            print("  > \(bullet.note?.title ?? "no title")")

            for (index, bullet) in bullets.enumerated() {
                print("    ", terminator: "")

                for _ in 0...index {
                    print(" ", terminator: "")
                }

                print("[\(bullet.orderIndex)] \(bullet.content ?? "no content")")
            }
        }
    }

    func treeBullets() -> [Any] {
        let results = rootBullets().compactMap { $0.treeBullets() }

        return results
    }

    override var debugDescription: String {
        return title ?? "No title"
    }

    /// To only be used to get the max orderIndex of the children bullets
    /// - Parameter context: <#context description#>
    /// - Returns: the current max orderIndex
    func maxBulletsOrderIndex(_ context: NSManagedObjectContext, _ parentBullet: Bullet? = nil) -> Int32 {
        guard let bullets = bullets, bullets.count > 0 else { return 0 }

//        let sortDescriptors = [NSSortDescriptor(keyPath: \Bullet.orderIndex, ascending: false)]
//        let bullet = bullets.sortedArray(using: [NSSortDescriptor(keyPath: \Bullet.orderIndex, ascending: false)]).first as? Bullet

        let bullet = rootBullets().last

        return max(Bullet.maxOrderIndex(context, note: self), bullet?.orderIndex ?? 0)
    }

    func rootBullets() -> [Bullet] {
        guard let bullets = bullets, bullets.count > 0 else { return [] }

        let predicate = NSPredicate(format: "parent == nil")

        let rootBullets = Array(bullets.filtered(using: predicate)).compactMap { $0 as? Bullet }

        return rootBullets.sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    func sortedBullets(_ context: NSManagedObjectContext) -> [Bullet] {
        let fetchRequest: NSFetchRequest<Bullet> = Bullet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "note = %@", self)
        fetchRequest.sortDescriptors =  [NSSortDescriptor(key: "orderIndex", ascending: true)]

        do {
            let fetchedBullets = try context.fetch(fetchRequest)
            return fetchedBullets
        } catch {
            // TODO: raise error?
        }

        return []
    }

    class func fetchAll(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil) -> [Note] {
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        fetchRequest.predicate = predicate

        do {
            let fetchedNotes = try context.fetch(fetchRequest)
            return fetchedNotes
        } catch {
            // TODO: raise error?
        }

        return []
    }

    class func fetchWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Note? {
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id = %@", id as CVarArg)

        do {
            let fetchedNotes = try context.fetch(fetchRequest)
            if fetchedNotes.count > 0 {
                return fetchedNotes[0]
            }
        } catch {
            // TODO: raise error?
        }

        return nil
    }

    class func fetchWithTitle(_ context: NSManagedObjectContext, _ title: String) -> Note? {
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title = %@", title as CVarArg)

        do {
            let fetchedNotes = try context.fetch(fetchRequest)
            if fetchedNotes.count > 0 {
                return fetchedNotes[0]
            }
        } catch {
            // TODO: raise error?
        }

        return nil
    }

    class func fetchAllWithTitleMatch(_ context: NSManagedObjectContext, _ title: String) -> [Note] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", title as CVarArg)
        return fetchAll(context: context, predicate)
    }

    class func countWithPredicate(_ context: NSManagedObjectContext, _ predicate: NSPredicate? = nil) -> Int {
        // Fetch existing if any
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        fetchRequest.predicate = predicate

        do {
            let fetchedTransactions = try context.count(for: fetchRequest)
            return fetchedTransactions
        } catch {
            // TODO: raise error?
        }

        return 0
    }
}
