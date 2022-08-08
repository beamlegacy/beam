import Foundation
import CoreData
import BeamCore

extension Document {
    @NSManaged public var id: UUID
    @NSManaged public var data: Data?
    @NSManaged public var deleted_at: Date?
    @NSManaged public var created_at: Date
    @NSManaged public var updated_at: Date
    @NSManaged public var title: String
    @NSManaged public var document_type: Int16
    @NSManaged public var version: Int64
    @NSManaged public var is_public: Bool
    @NSManaged public var database_id: UUID
    @NSManaged public var journal_day: Int64

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
