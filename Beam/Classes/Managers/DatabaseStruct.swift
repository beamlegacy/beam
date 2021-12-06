import Foundation
import BeamCore

struct DatabaseStruct: BeamObjectProtocol {
    static var beamObjectType = BeamObjectObjectType.database

    var id: UUID = .null
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

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
                       deletedAt: deletedAt
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
    }

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = BeamDate.now
        self.updatedAt = BeamDate.now
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
