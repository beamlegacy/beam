import Foundation

class DatabaseAPIType: Codable, Equatable {
    static func == (lhs: DatabaseAPIType, rhs: DatabaseAPIType) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title
    }

    var id: String?
    var title: String?
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?

    init(id: String) {
        self.id = id
    }

    init(database: DatabaseStruct) {
        title = database.title
        id = database.uuidString
        createdAt = database.createdAt
        deletedAt = database.deletedAt
        updatedAt = database.updatedAt
    }

    init(database: Database) {
        title = database.title
        id = database.uuidString
        createdAt = database.created_at
        deletedAt = database.deleted_at
        updatedAt = database.updated_at
    }
}
