import Foundation

public struct DocumentStruct {
    var id: UUID
    var databaseId: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var data: Data
    let documentType: DocumentType
    var previousData: Data?
    var previousChecksum: String?
    var version: Int64
    var isPublic: Bool = false

    var uuidString: String {
        id.uuidString.lowercased()
    }

    mutating func clearPreviousData() {
        previousData = nil
        previousChecksum = nil
    }

    func copy() -> DocumentStruct {
        let copy = DocumentStruct(id: id,
                                  databaseId: databaseId,
                                  title: title,
                                  createdAt: createdAt,
                                  updatedAt: updatedAt,
                                  deletedAt: deletedAt,
                                  data: data,
                                  documentType: documentType,
                                  previousData: previousData,
                                  previousChecksum: previousChecksum,
                                  version: version,
                                  isPublic: isPublic
                                  )
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
        self.previousChecksum = document.beam_api_checksum
        self.version = document.version
        self.isPublic = document.is_public
        self.databaseId = document.database_id
    }

    func asApiType() -> DocumentAPIType {
        let result = DocumentAPIType(document: self)
        return result
    }
}
