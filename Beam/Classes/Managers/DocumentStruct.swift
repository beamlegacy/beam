import Foundation

enum NoteType: String, Codable {
    case journal
    case note
}

public struct DocumentStruct {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var data: Data
    let documentType: DocumentType
    var previousChecksum: String?
    var previousData: Data?

    var uuidString: String {
        id.uuidString.lowercased()
    }

    var previousDataString: String? {
        guard let previousData = previousData else { return nil }
        return previousData.asString
    }

    mutating func clearPreviousData() {
        previousChecksum = nil
        previousData = nil
    }

    func copy() -> DocumentStruct {
        let copy = DocumentStruct(id: id,
                                  title: title,
                                  createdAt: createdAt,
                                  updatedAt: updatedAt,
                                  deletedAt: deletedAt,
                                  data: data,
                                  documentType: documentType,
                                  previousChecksum: previousChecksum,
                                  previousData: previousData)
        return copy
    }
}

extension DocumentStruct {
    init(document: Document) {
        self.id = document.id
        self.createdAt = document.created_at
        self.updatedAt = document.updated_at
        self.title = document.title
        self.documentType = DocumentType(rawValue: document.document_type) ?? .note
        self.data = document.data ?? Data()
        self.previousData = document.beam_api_data
        self.previousChecksum = document.beam_api_data?.MD5
    }

    func asApiType() -> DocumentAPIType {
        let result = DocumentAPIType(document: self)
        return result
    }
}
