import Foundation
import CoreData

/*
 When changing this, you *must* let backend know. We have to add new values to
 `app/models/document.rb` in our API codebase.
 */
public enum DocumentType: Int16, Codable {
    case journal
    case note
}

extension Document {
    //swiftlint:disable identifier_name
    @NSManaged public var id: UUID
    @NSManaged public var data: Data?
    @NSManaged public var beam_api_data: Data?
    @NSManaged public var beam_api_checksum: String?
    @NSManaged public var beam_object_previous_checksum: String?
    @NSManaged public var beam_api_sent_at: Date?
    @NSManaged public var deleted_at: Date?
    @NSManaged public var created_at: Date
    @NSManaged public var updated_at: Date
    @NSManaged public var title: String
    @NSManaged public var document_type: Int16
    @NSManaged public var version: Int64
    @NSManaged public var is_public: Bool
    @NSManaged public var database_id: UUID
    @NSManaged public var journal_day: Int64
    //swiftlint:enable identifier_name

    public var documentType: DocumentType {
        guard let type = DocumentType(rawValue: document_type) else {
            // We should always have a type
            assert(false)
            return DocumentType.note
        }
        return type
    }
}

extension Document: Identifiable {

}
