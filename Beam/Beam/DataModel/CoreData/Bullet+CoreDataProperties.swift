import Foundation
import CoreData

extension Bullet {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Bullet> {
        return NSFetchRequest<Bullet>(entityName: "Bullet")
    }

    @NSManaged public var content: String
    @NSManaged public var created_at: Date
    @NSManaged public var id: UUID
    @NSManaged public var orderIndex: Int32
    @NSManaged public var updated_at: Date
    @NSManaged public var children: Set<Bullet>?
    @NSManaged public var linkedNotes: Set<Note>?
    @NSManaged public var note: Note?
    @NSManaged public var parent: Bullet?
    @NSManaged public var unlinkedNotes: Set<Note>?
    @NSManaged public var score: NSNumber?

}

// MARK: Generated accessors for children
extension Bullet {

    @objc(addChildrenObject:)
    @NSManaged public func addToChildren(_ value: Bullet)

    @objc(removeChildrenObject:)
    @NSManaged public func removeFromChildren(_ value: Bullet)

    @objc(addChildren:)
    @NSManaged public func addToChildren(_ values: Set<Bullet>)

    @objc(removeChildren:)
    @NSManaged public func removeFromChildren(_ values: Set<Bullet>)

}

// MARK: Generated accessors for linkedNotes
extension Bullet {

    @objc(addLinkedNotesObject:)
    @NSManaged public func addToLinkedNotes(_ value: Note)

    @objc(removeLinkedNotesObject:)
    @NSManaged public func removeFromLinkedNotes(_ value: Note)

    @objc(addLinkedNotes:)
    @NSManaged public func addToLinkedNotes(_ values: Set<Note>)

    @objc(removeLinkedNotes:)
    @NSManaged public func removeFromLinkedNotes(_ values: Set<Note>)

}

// MARK: Generated accessors for unlinkedNotes
extension Bullet {

    @objc(addUnlinkedNotesObject:)
    @NSManaged public func addToUnlinkedNotes(_ value: Note)

    @objc(removeUnlinkedNotesObject:)
    @NSManaged public func removeFromUnlinkedNotes(_ value: Note)

    @objc(addUnlinkedNotes:)
    @NSManaged public func addToUnlinkedNotes(_ values: Set<Note>)

    @objc(removeUnlinkedNotes:)
    @NSManaged public func removeFromUnlinkedNotes(_ values: Set<Note>)

}

extension Bullet: Identifiable {

}
