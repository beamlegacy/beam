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
        documentType = document.document_type
        previousChecksum = document.data?.MD5

        if let documentData = document.data,
           let documentParsedData = String(data: documentData, encoding: .utf8) {
            data = documentParsedData
        }
    }

    init(document: DocumentStruct) {
        title = document.title
        id = document.uuidString
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        deletedAt = document.deletedAt
        previousChecksum = document.previousChecksum

        if let documentParsedData = String(data: document.data, encoding: .utf8) {
            data = documentParsedData
        }
    }

    init(id: String) {
        self.id = id
    }
}
