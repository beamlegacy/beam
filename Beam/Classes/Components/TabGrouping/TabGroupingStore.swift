//
//  TabGroupingStore.swift
//  Beam
//
//  Created by Remi Santos on 16/06/2022.
//

import Foundation
import BeamCore
import GRDB

/// Database representation of a Tab Group (aka `Beam.TabGroup`), conforming to BeamObjectProtocol.
struct TabGroupBeamObject {

    var id: UUID
    var title: String?
    var color: TabGroupingColor?
    var pages: [PageInfo] = []

    /// locked is for a tab group that has been frozen to be inserted into a Note or shared.
    var isLocked: Bool = false

    // BeamObject defaults
    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    var deletedAt: Date?

    struct PageInfo: Codable, DatabaseValueConvertible {
        let id: ClusteringManager.PageID
        let url: URL
        let title: String

        /// a screenshot of the page's webview when the group is saved.
        var snapshot: Data?
    }
}

// MARK: - Store
class TabGroupsStore {
    private let db: GRDBDatabase

    init(db: GRDBDatabase = GRDBDatabase.shared) {
        self.db = db
    }

    func save(_ group: TabGroupBeamObject) {
        db.saveTabGroups([group])
    }

    func fetch(byIds ids: [UUID]) -> [TabGroupBeamObject] {
        db.getTabGroups(ids: ids)
    }

    func fetch(byTitle title: String) -> [TabGroupBeamObject] {
        db.getTabGroups(matchingTitle: title)
    }

    func cleanup() {
        db.deleteAllTabGroups()
    }
}

// MARK: - BeamObject Conformance
extension TabGroupBeamObject: BeamObjectProtocol {
    static var beamObjectType: BeamObjectObjectType {
        BeamObjectObjectType.tabGroup
    }

    static func == (lhs: TabGroupBeamObject, rhs: TabGroupBeamObject) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var beamObjectId: UUID {
        get { id }
        set { id = newValue }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case color
        case pages
        case isLocked
        case createdAt
        case updatedAt
        case deletedAt
    }

    private struct CodableColor: Codable, DatabaseValueConvertible {
        var colorName: String?
        var hueTint: Double?
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
        title = try values.decode(String.self, forKey: .title)
        let codableColor = try values.decode(CodableColor.self, forKey: .color)
        color = TabGroupingColor(designColor: .init(rawValue: codableColor.colorName ?? ""), randomColorHueTint: codableColor.hueTint)
        pages = try values.decode([PageInfo].self, forKey: .pages)
        isLocked = try values.decode(Bool.self, forKey: .isLocked)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(CodableColor(colorName: color?.designColor?.rawValue, hueTint: color?.randomColorHueTint), forKey: .color)
        try container.encode(pages, forKey: .pages)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        if deletedAt != nil {
            try container.encode(deletedAt, forKey: .deletedAt)
        }
    }

    func copy() throws -> TabGroupBeamObject {
        TabGroupBeamObject(id: id, title: title, color: color, pages: pages,
                           createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt)
    }
}

extension TabGroupBeamObject: TableRecord {
    enum Columns: String, ColumnExpression {
        case id, title, colorName, colorHue, pages, isLocked, createdAt, updatedAt, deletedAt
    }
    static var databaseTableName = "TabGroup"
}

extension TabGroupBeamObject: FetchableRecord {

    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        let colorName: String? = row[Columns.colorName]
        let colorHue: Double? = row[Columns.colorHue]
        color = TabGroupingColor(designColor: .init(rawValue: colorName ?? ""), randomColorHueTint: colorHue)
        if let data = row[Columns.pages] as? Data {
            let decodedPages = try? BeamJSONDecoder().decode([PageInfo].self, from: data)
            pages = decodedPages ?? []
        } else {
            pages = []
        }
        isLocked = row[Columns.isLocked]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        deletedAt = row[Columns.deletedAt]
    }
}

extension TabGroupBeamObject: MutablePersistableRecord {
    /// The values persisted in the database
    static let persistenceConflictPolicy = PersistenceConflictPolicy( insert: .replace, update: .replace)

    func encode(to container: inout PersistenceContainer) {
        container[Columns.title] = title
        container[Columns.id] = id
        container[Columns.colorName] = color?.designColor?.rawValue
        container[Columns.colorHue] = color?.randomColorHueTint
        container[Columns.pages] = try? JSONEncoder().encode(pages)
        container[Columns.isLocked] = isLocked
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.deletedAt] = deletedAt
    }
}

// MARK: - Migrations

extension TabGroupsStore {
    static func registerMigration(with migrator: inout DatabaseMigrator) {

        migrator.registerMigration("createTabGroupTable") { db in
            try db.create(table: "TabGroup", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey().unique()
                t.column("title", .text).notNull()
                t.column("colorName", .text)
                t.column("colorHue", .double)
                t.column("pages", .blob).notNull()
                t.column("isLocked", .boolean).notNull()
                t.column("createdAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("deletedAt", .datetime)
            }
        }

    }
}
