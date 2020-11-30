import Foundation
import CoreData

enum DocumentType: Int16 {
    case journal
    case note
}

extension Document {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Document> {
        return NSFetchRequest<Document>(entityName: "Document")
    }

    //swiftlint:disable identifier_name
    @NSManaged public var created_at: Date
    @NSManaged public var id: UUID
    @NSManaged public var data: Data?
    @NSManaged public var title: String
    @NSManaged public var updated_at: Date
    @NSManaged public var documentType: Int16
    @NSManaged public var score: Int16
    //swiftlint:enable identifier_name
}

extension Document: Identifiable {

}
