import Foundation

struct DocumentAPIType: Codable {
    var id: String?
    var title: String?
    var isPublic: Bool?
    var createdAt: Date?
    var updatedAt: Date?
    var data: String?

    init(document: Document) {
        title = document.title
        id = document.uuidString
        createdAt = document.created_at
        updatedAt = document.updated_at

        if let documentData = document.data,
           let documentParsedData = String(data: documentData, encoding: .utf8) {
            data = documentParsedData
        }
    }

    init(document: DocumentStruct) {
        title = document.title
        id = document.id.uuidString.lowercased()
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        if let documentParsedData = String(data: document.data, encoding: .utf8) {
            data = documentParsedData
        }
    }

    init(id: String) {
        self.id = id
    }
}
