import Foundation

public struct DocumentStruct: BeamObjectProtocol {
    var uuid: String {
        id.uuidString.lowercased()
    }
    var beamObjectPreviousChecksum: String?

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
    var version: Int64 = 0
    var isPublic: Bool = false

    var uuidString: String {
        id.uuidString.lowercased()
    }

    // Used for encoding this into BeamObject
    enum CodingKeys: String, CodingKey {
        case id
        case databaseId
        case title
        case createdAt
        case updatedAt
        case deletedAt
        case data
        case documentType
        case isPublic
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
        self.deletedAt = document.deleted_at
        self.title = document.title
        self.documentType = DocumentType(rawValue: document.document_type) ?? .note
        self.data = document.data ?? Data()
        self.previousData = document.beam_api_data
        self.previousChecksum = document.beam_api_checksum
        self.version = document.version
        self.isPublic = document.is_public
        self.databaseId = document.database_id
        self.beamObjectPreviousChecksum = document.beam_object_previous_checksum
    }

    func asApiType() -> DocumentAPIType {
        let result = DocumentAPIType(document: self)
        return result
    }
}
