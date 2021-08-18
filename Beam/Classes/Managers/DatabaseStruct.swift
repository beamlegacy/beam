import Foundation
import BeamCore

struct DatabaseStruct: BeamObjectProtocol {
    static var beamObjectTypeName: String { "database" }

    var id: UUID = .null
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

    var beamObjectId: UUID {
        get { id }
        set { id = newValue }
    }

    // Used for encoding this into BeamObject
    enum CodingKeys: String, CodingKey {
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

    var titleAndId: String {
        "\(title) {\(id)}"
    }
}

extension DatabaseStruct: Equatable {
    static public func == (lhs: DatabaseStruct, rhs: DatabaseStruct) -> Bool {

        // Server side doesn't store milliseconds for updatedAt and createdAt.
        // Local coredata does, rounding using Int() to compare them

        lhs.id == rhs.id &&
            lhs.title == rhs.title &&
            lhs.createdAt.intValue == rhs.createdAt.intValue &&
            lhs.updatedAt.intValue == rhs.updatedAt.intValue &&
            lhs.deletedAt?.intValue == rhs.deletedAt?.intValue
    }
}

extension DatabaseStruct: Hashable {

}
