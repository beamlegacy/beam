import Foundation
import CoreData

/*
 When changing this, you *must* let backend know. We have to add new values to
 `app/models/document.rb` in our API codebase.
 */
enum DocumentType: Int16 {
    case journal
    case note
}

extension Document {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Document> {
        return NSFetchRequest<Document>(entityName: "Document")
    }

    //swiftlint:disable identifier_name
    @NSManaged public var id: UUID
    @NSManaged public var data: Data?
    @NSManaged public var beam_api_data: Data?
    @NSManaged public var deleted_at: Date?
    @NSManaged public var created_at: Date
    @NSManaged public var updated_at: Date
    @NSManaged public var title: String
    @NSManaged public var document_type: Int16
    @NSManaged public var score: Int16
    //swiftlint:enable identifier_name
}

extension Document: Identifiable {

}
