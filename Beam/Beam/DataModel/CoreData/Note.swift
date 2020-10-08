import Foundation
import CoreData
import os.log

class Note: NSManagedObject {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        created_at = Date()
        id = UUID()
    }

    @discardableResult
    class func createNote(_ context: NSManagedObjectContext, _ title: String) -> Note {
        guard let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: context) as? Note else {
            fatalError("Couldn't create entity Note")
        }
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
        guard let newBullet = NSEntityDescription.insertNewObject(forEntityName: "Bullet", into: context) as? Bullet else {
            fatalError("Couldn't create entity Bullet")
        }

        newBullet.content = content
        newBullet.note = self
        newBullet.parent = parentBullet ?? afterBullet?.parent

        let atIndex = parentBullet != nil ? 0 : afterBullet?.orderIndex

        newBullet.orderIndex = (atIndex ?? maxBulletsOrderIndex(context)) + 1

        // Move all bullets lower
        if let atIndex = atIndex, let bullets = bullets {
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

    func debugNote() {
        let tree = treeBullets()
        displayBullets(tree)
    }

    func displayBullets(_ tree: [Any], _ tabCount: Int = 0) {
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

    func treeBullets() -> [Any] {
        let results = rootBullets().compactMap { $0.treeBullets() }

        return results
    }

    override var debugDescription: String {
        return title ?? "No title"
    }

    /// To only be used to get the max orderIndex of the root bullets (without parent bullets)
    /// - Parameter context: <#context description#>
    /// - Returns: the current max orderIndex
    func maxBulletsOrderIndex(_ context: NSManagedObjectContext) -> Int32 {
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

    func sortedRootBullets(_ context: NSManagedObjectContext) -> [Bullet] {
        let fetchRequest: NSFetchRequest<Bullet> = Bullet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "note = %@ AND parent == nil", self)
        fetchRequest.sortDescriptors =  [NSSortDescriptor(key: "orderIndex", ascending: true)]

        do {
            let fetchedBullets = try context.fetch(fetchRequest)
            return fetchedBullets
        } catch {
            // TODO: raise error?
        }

        return []
    }

    class func fetchAll(context: NSManagedObjectContext) -> [Note] {
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()

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
