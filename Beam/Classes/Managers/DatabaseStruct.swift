import Foundation

struct DatabaseStruct: BeamObjectProtocol {
    var uuid: String {
        id.uuidString.lowercased()
    }

    static var beamObjectTypeName: String { "database" }

    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var previousChecksum: String?
    var checksum: String?
    var beamObjectPreviousChecksum: String?

    var uuidString: String {
        id.uuidString.lowercased()
    }

    // Used for encoding this into BeamObject
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case updatedAt
        case deletedAt
    }

    func copy() -> DatabaseStruct {
        DatabaseStruct(id: id,
                       title: title,
                       createdAt: createdAt,
                       updatedAt: updatedAt,
                       deletedAt: deletedAt,
                       previousChecksum: previousChecksum,
                       beamObjectPreviousChecksum: beamObjectPreviousChecksum
        )
    }
}

extension DatabaseStruct {
    init(database: Database) {
        self.id = database.id
        self.createdAt = database.created_at
        self.updatedAt = database.updated_at
        self.deletedAt = database.deleted_at
        self.title = database.title
        self.beamObjectPreviousChecksum = database.beam_object_previous_checksum
    }

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = BeamDate.now
        self.updatedAt = BeamDate.now
    }

    func asApiType() -> DatabaseAPIType {
        let result = DatabaseAPIType(database: self)
        return result
    }
}

extension DatabaseStruct: Equatable {
    static public func == (lhs: DatabaseStruct, rhs: DatabaseStruct) -> Bool {
        lhs.id == rhs.id
    }
}

extension DatabaseStruct: Hashable {

}
