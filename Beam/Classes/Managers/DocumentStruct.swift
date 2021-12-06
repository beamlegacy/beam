import Foundation
import BeamCore

struct DocumentStruct: BeamObjectProtocol {
    static var beamObjectTypeName: String { "document" }

    var id: UUID = .null
    var databaseId: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var data: Data
    var documentType: DocumentType
    var previousData: Data?
    var previousChecksum: String?
    var version: Int64 = 0
    var isPublic: Bool = false
    var checksum: String?
    var beamObjectPreviousChecksum: String?

    var beamObjectId: UUID {
        get { id }
        set { id = newValue }
    }
    var journalDate: String?

    var uuidString: String {
        id.uuidString.lowercased()
    }

    var titleAndId: String {
        "\(title) {\(id)} v\(version)"
    }

    var isEmpty: Bool {
        do {
            let beamNote = try BeamNote.instanciateNote(self,
                                                        keepInMemory: false,
                                                        decodeChildren: true,
                                                        verifyDatabase: false)
            guard beamNote.isEntireNoteEmpty() else { return false }

            return true
        } catch {
            Logger.shared.logError("Can't decode DocumenStruct \(titleAndId)", category: .document)
        }

        return false
    }

    mutating func clearPreviousData() {
        previousData = nil
        previousChecksum = nil
    }

    func copy() -> DocumentStruct {
        DocumentStruct(documentStruct: self)
    }
}

extension DocumentStruct {
    // Used for encoding this into BeamObject. Update `encode` and `init()` when adding values here
    enum CodingKeys: String, CodingKey {
        case databaseId
        case title
        case createdAt
        case updatedAt
        case deletedAt
        case data
        case documentType
        case isPublic
        case journalDate
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        databaseId = UUID(uuidString: try values.decode(String.self, forKey: .databaseId)) ?? .null
        title = try values.decode(String.self, forKey: .title)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
        isPublic = try values.decode(Bool.self, forKey: .isPublic)
        journalDate = try values.decodeIfPresent(String.self, forKey: .journalDate)
        data = try values.decode(String.self, forKey: .data).asData

        let documentTypeAsString = try values.decode(String.self, forKey: .documentType)
        switch documentTypeAsString {
        case "journal":
            documentType = .journal
        case "note":
            documentType = .note
        default:
            documentType = .note
            Logger.shared.logError("Can't decode \(documentTypeAsString)", category: .document)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(databaseId.uuidString.lowercased(), forKey: .databaseId)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        if deletedAt != nil {
            try container.encode(deletedAt, forKey: .deletedAt)
        }

        try container.encode(data.asString, forKey: .data)
        switch documentType {
        case .journal:
            try container.encode("journal", forKey: .documentType)
        case .note:
            try container.encode("note", forKey: .documentType)
        }

        try container.encode(isPublic, forKey: .isPublic)
        if journalDate != nil {
            try container.encode(journalDate, forKey: .journalDate)
        }
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
        self.journalDate = documentType == .journal ? JournalDateConverter.toString(from: document.journal_day) : nil
    }

    init(documentStruct: DocumentStruct) {
        self.id = documentStruct.id
        self.createdAt = documentStruct.createdAt
        self.updatedAt = documentStruct.updatedAt
        self.deletedAt = documentStruct.deletedAt
        self.title = documentStruct.title
        self.documentType = documentStruct.documentType
        self.data = documentStruct.data
        self.previousData = documentStruct.previousData
        self.previousChecksum = documentStruct.previousChecksum
        self.version = documentStruct.version
        self.isPublic = documentStruct.isPublic
        self.databaseId = documentStruct.databaseId
        self.beamObjectPreviousChecksum = documentStruct.beamObjectPreviousChecksum
        self.journalDate = documentStruct.journalDate
    }
}

extension DocumentStruct: Equatable {
    static public func == (lhs: DocumentStruct, rhs: DocumentStruct) -> Bool {

        // Server side doesn't store milliseconds for updatedAt and createdAt.
        // Local coredata does, rounding using Int() to compare them

        lhs.id == rhs.id &&
            lhs.title == rhs.title &&
            lhs.data == rhs.data &&
            lhs.documentType == rhs.documentType &&
            lhs.isPublic == rhs.isPublic &&
            lhs.databaseId == rhs.databaseId &&
            lhs.createdAt.intValue == rhs.createdAt.intValue &&
            lhs.updatedAt.intValue == rhs.updatedAt.intValue &&
            lhs.deletedAt?.intValue == rhs.deletedAt?.intValue &&
            lhs.journalDate == rhs.journalDate
    }
}

extension DocumentStruct: Hashable {

}

extension Document {
    var documentStruct: DocumentStruct {
        DocumentStruct(document: self)
    }
}
