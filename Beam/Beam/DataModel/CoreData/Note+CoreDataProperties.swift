import Foundation
import CoreData

enum NoteType: String {
    case journal
    case note
}

extension Note {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Note> {
        return NSFetchRequest<Note>(entityName: "Note")
    }

    //swiftlint:disable identifier_name
    @NSManaged public var created_at: Date
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var updated_at: Date
    @NSManaged public var bullets: Set<Bullet>?
    @NSManaged public var linkedReferences: Set<Bullet>?
    @NSManaged public var unlinkedReferences: Set<Bullet>?
    @NSManaged public var type: String
    @NSManaged public var score: NSNumber?
    //swiftlint:enable identifier_name
}

// MARK: Generated accessors for bullets
extension Note {

    @objc(addBulletsObject:)
    @NSManaged public func addToBullets(_ value: Bullet)

    @objc(removeBulletsObject:)
    @NSManaged public func removeFromBullets(_ value: Bullet)

    @objc(addBullets:)
    @NSManaged public func addToBullets(_ values: Set<Bullet>)

    @objc(removeBullets:)
    @NSManaged public func removeFromBullets(_ values: Set<Bullet>)

}

// MARK: Generated accessors for linkedReferences
extension Note {

    @objc(addLinkedReferencesObject:)
    @NSManaged public func addToLinkedReferences(_ value: Bullet)

    @objc(removeLinkedReferencesObject:)
    @NSManaged public func removeFromLinkedReferences(_ value: Bullet)

    @objc(addLinkedReferences:)
    @NSManaged public func addToLinkedReferences(_ values: Set<Bullet>)

    @objc(removeLinkedReferences:)
    @NSManaged public func removeFromLinkedReferences(_ values: Set<Bullet>)

}

// MARK: Generated accessors for unlinkedReferences
extension Note {

    @objc(addUnlinkedReferencesObject:)
    @NSManaged public func addToUnlinkedReferences(_ value: Bullet)

    @objc(removeUnlinkedReferencesObject:)
    @NSManaged public func removeFromUnlinkedReferences(_ value: Bullet)

    @objc(addUnlinkedReferences:)
    @NSManaged public func addToUnlinkedReferences(_ values: Set<Bullet>)

    @objc(removeUnlinkedReferences:)
    @NSManaged public func removeFromUnlinkedReferences(_ values: Set<Bullet>)

}

extension Note: Identifiable {

}
