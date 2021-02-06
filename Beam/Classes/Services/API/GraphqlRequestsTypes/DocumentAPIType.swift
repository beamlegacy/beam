import Foundation

class DocumentAPIType: Codable {
    var id: String?
    var title: String?
    var isPublic: Bool?
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?
    var data: String?
    var documentType: Int16?
    var previousChecksum: String?

    init(document: Document) {
        title = document.title
        id = document.uuidString
        createdAt = document.created_at
        updatedAt = document.updated_at
        deletedAt = document.deleted_at
        documentType = document.document_type
        previousChecksum = document.data?.MD5
        data = document.data?.asString
    }

    init(document: DocumentStruct) {
        title = document.title
        id = document.uuidString
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        deletedAt = document.deletedAt
        documentType = document.documentType.rawValue
        previousChecksum = document.previousChecksum ?? document.previousData?.MD5
        data = document.data.asString
    }

    init(id: String) {
        self.id = id
    }
}
