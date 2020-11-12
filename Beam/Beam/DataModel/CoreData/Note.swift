import Foundation
import CoreData
import Down

//swiftlint:disable file_length
class Note: NSManagedObject {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        created_at = Date()
        updated_at = Date()
        id = UUID()
    }

    @discardableResult
    class func createNote(_ context: NSManagedObjectContext, _ title: String, createdAt: Date? = nil, type: NoteType = .note) -> Note {
        let existingNote = fetchWithTitle(context, title)

        let note = existingNote ?? Note(context: context)

        note.title = title
        note.created_at = createdAt ?? Date()
        note.type = type.rawValue

        return note
    }

    func internalLink() -> String {
        var result = Self.components()
        result.queryItems = [ URLQueryItem(name: "id", value: id.uuidString) ]

        return result.url?.absoluteString ?? "beam://"
    }

    class func internalLink(_ title: String) -> String {
        var result = components()
        result.queryItems = [ URLQueryItem(name: "title", value: title) ]

        return result.url?.absoluteString ?? "beam://"
    }

    class func components() -> URLComponents {
        var components = URLComponents()

        components.scheme = "beam"
        components.host = Config.hostname
        components.path = "/note"

        return components
    }

    func parsedTitle() -> String {
        return BeamTextFormatter.parseForInternalLinks(title)
    }

    /// Will set the `orderIndex` properly, based on `afterBullet`
    /// - Parameters:
    ///   - context: <#context description#>
    ///   - content: <#content description#>
    ///   - afterBullet: <#afterBullet description#>
    /// - Returns: thre created `Bullet`
    func createBullet(_ context: NSManagedObjectContext, content: String, createdAt: Date? = nil, afterBullet: Bullet? = nil, parentBullet: Bullet? = nil) -> Bullet {
        let newBullet = Bullet(context: context)

        newBullet.content = content
        newBullet.note = self
        newBullet.parent = parentBullet ?? afterBullet?.parent
        newBullet.created_at = createdAt ?? Date()

        let atIndex = afterBullet?.orderIndex ?? Bullet.maxOrderIndex(context, newBullet.parent, note: self)

        newBullet.orderIndex = atIndex + 1

        // Move all bullets lower
        if let bullets = bullets {
            // TODO: ugly, refactor
            for bullet in bullets where (bullet.orderIndex > atIndex) && (bullet.id != newBullet.id) && bullet.parent == newBullet.parent {
                bullet.orderIndex += 1
            }
        }

        return newBullet
    }

    class func detectUnlinkedNotes(_ context: NSManagedObjectContext) {
        for note in Note.fetchAllWithPredicate(context: context) {
            note.detectUnlinkedNotes(context)
        }
    }

    func detectUnlinkedNotes(_ context: NSManagedObjectContext) {
        let predicate = NSPredicate(format: "content CONTAINS[cd] %@", title)

        for bullet in Bullet.fetchAllWithPredicate(context, predicate) {
            if linkedReferences?.contains(bullet) ?? false { continue }

            addToUnlinkedReferences(bullet)
        }
    }

    func debugNote() {
        print("> \(title)")

        let tree = treeBullets()

        print(displayBullets(tree))
        print(displayLinkedReferences())
        print(displayUnlinkedReferences())
        print("")
    }

    func fullContent() -> String {
        var result = ""

        result.append("\(title) \(updated_at)\n")
        let tree = treeBullets()

        result.append(displayBullets(tree))
        result.append(displayLinkedReferences())
        result.append(displayUnlinkedReferences())
        result.append("\n")

        return result
    }

    func attributedString(_ parsedInternalLink: Bool = true) -> NSAttributedString? {
        var content = ""

        content.append("\(parsedInternalLink ? parsedTitle() : title)\n\n")
        let tree = treeBullets()

        content.append(displayBullets(tree, 0, parsedInternalLink))
        content.append(displayLinkedReferences(parsedInternalLink))
        content.append(displayUnlinkedReferences(parsedInternalLink))
        content.append("\n")

        let down = Down(markdownString: content)
        let result = try? down.toAttributedString(.default, styler: DownStyler())

        return result
    }

    private func displayBullets(_ tree: [Any], _ tabCount: Int = 0, _ parsedInternalLink: Bool = false) -> String {
        var result = ""

        for elements in tree {
            if let elements = elements as? [Any] {
                result.append(displayBullets(elements, tabCount + 1, parsedInternalLink))
                result.append("\n")
            } else if let element = elements as? Bullet {
                for _ in 0...tabCount {
                    result.append(" ")
                }
                if parsedInternalLink {
                    result.append("- [@](\(element.internalLink())) \(element.parsedContent(parsedInternalLink))\n")
                } else {
                    result.append("- \(element.parsedContent(parsedInternalLink))\n")
                }
            } else {
                result.append("- Not Found for \(elements)\n")
            }
        }

        return result
    }

    private func displayLinkedReferences(_ parsedInternalLink: Bool = false) -> String {
        guard let linkedReferences = linkedReferences, linkedReferences.count > 0 else { return "" }

        var result = ""

        result.append("\n  \(linkedReferences.count) Linked References\n")

        result.append(displayReferences(linkedReferences, parsedInternalLink))

        return result
    }

    private func displayUnlinkedReferences(_ parsedInternalLink: Bool = false) -> String {
        guard let unlinkedReferences = unlinkedReferences, unlinkedReferences.count > 0 else { return "" }

        var result = ""

        result.append("\n  \(unlinkedReferences.count) Unlinked References\n")

        result.append(displayReferences(unlinkedReferences, parsedInternalLink))

        return result
    }

    private func displayReferences(_ bullets: Set<Bullet>, _ parsedInternalLink: Bool = false) -> String {
        var result = ""

        // We want to join bullets by note to list them all together
        var notes: [Note: [Bullet]] = [:]
        bullets.forEach { bullet in
            guard let note = bullet.note else { return }
            notes[note] = notes[note] ?? []
            notes[note]?.append(bullet)
        }

        // We want to sort notes based on bullet last update time
        let sortedNotes = notes.sorted {
            guard let first = $0.value.sorted(by: { $0.updated_at > $1.updated_at }).first?.updated_at,
                  let second = $1.value.sorted(by: { $0.updated_at > $1.updated_at }).first?.updated_at
            else { return false }

            return first > second
        }

        print(notes)

        for note in sortedNotes {
            guard let bullets = notes[note.key] else { continue }

            if parsedInternalLink {
                result.append("  - [@](\(note.key.internalLink())) \(note.key.parsedTitle())\n")
            } else {
                result.append("  - \(note.key.title)\n")
            }

            for bullet in bullets {
                var currentBullet = bullet
                var bullets: [Bullet] = [currentBullet]
                while let parentBullet = currentBullet.parent {
                    bullets.insert(parentBullet, at: 0)
                    currentBullet = parentBullet
                }

                for (index, bullet) in bullets.enumerated() {
                    result.append("    ")

                    for _ in 0...index {
                        result.append("   ")
                    }

                    if parsedInternalLink {
                        result.append("- [@](\(bullet.internalLink())) \(bullet.parsedContent(parsedInternalLink))\n")
                    } else {
                        result.append("- \(bullet.content)\n")
                    }
                }
            }
        }

        return result
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

                print("[\(bullet.orderIndex)] \(bullet.content)")
            }
        }
    }

    func treeBullets() -> [Any] {
        let results = rootBullets().compactMap { $0.treeBullets() }

        return results
    }

    override var debugDescription: String {
        return title
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
        guard let bullets = bullets, !bullets.isEmpty else { return [] }

        let rootBullets = bullets.filter { $0.parent == nil }

        return rootBullets.sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    func sortedBullets(_ context: NSManagedObjectContext) -> [Bullet] {
        let fetchRequest: NSFetchRequest<Bullet> = Bullet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "note = %@", self)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]

        do {
            let fetchedBullets = try context.fetch(fetchRequest)
            return fetchedBullets
        } catch {
            // TODO: raise error?
        }

        return []
    }

    // MARK: - CoreData Helpers
    class func fetchAllWithPredicate(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil) -> [Note] {
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors

        do {
            let fetchedNotes = try context.fetch(fetchRequest)
            return fetchedNotes
        } catch {
            // TODO: raise error?
        }

        return []
    }

    class func fetchFirst(context: NSManagedObjectContext, _ predicate: NSPredicate? = nil, _ sortDescriptors: [NSSortDescriptor]? = nil) -> Note? {
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
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

    class func fetchWithId(_ context: NSManagedObjectContext, _ id: UUID) -> Note? {
        return fetchFirst(context: context, NSPredicate(format: "id = %@", id as CVarArg))
    }

    class func fetchWithTitle(_ context: NSManagedObjectContext, _ title: String) -> Note? {
        return fetchFirst(context: context, NSPredicate(format: "title = %@", title as CVarArg))
    }

    class func fetchAllWithType(_ context: NSManagedObjectContext, _ type: NoteType) -> [Note] {
        let predicate = NSPredicate(format: "type == %@", type.rawValue as CVarArg)
        return fetchAllWithPredicate(context: context, predicate, [NSSortDescriptor(keyPath: \Note.created_at, ascending: false)])
    }

    class func fetchAllWithTitleMatch(_ context: NSManagedObjectContext, _ title: String) -> [Note] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", title as CVarArg)
        return fetchAllWithPredicate(context: context, predicate)
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

    func delete(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext) {
        context.delete(self)
        do {
            try context.save()
        } catch {
            // TODO: raise error?
        }
    }

    class func deleteForPredicate(_ predicate: NSPredicate, _ context: NSManagedObjectContext) -> NSPersistentStoreResult? {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Note")
        fetch.predicate = predicate
        fetch.includesSubentities = false
        fetch.includesPropertyValues = false

        let request = NSBatchDeleteRequest(fetchRequest: fetch)
        request.resultType = .resultTypeObjectIDs
        do {
            #if DEBUG
            let count = try context.count(for: fetch)
            if count > 0 {
                NSLog("Deleted \(count) notes")
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
//swiftlint:enable file_length
