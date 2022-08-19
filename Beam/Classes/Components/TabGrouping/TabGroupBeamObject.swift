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
struct TabGroupBeamObject: Identifiable {

    var id: UUID = UUID()
    var title: String?
    var color: TabGroupingColor?
    var pages: [PageInfo] = []

    /// locked is for a tab group that has been frozen to be inserted into a Note or shared.
    var isLocked: Bool = false

    /// a locked group can be the copy of a parent group, for sharing.
    var parentGroup: UUID?

    // BeamObject defaults
    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    var deletedAt: Date?

    struct PageInfo: Codable, Identifiable, Hashable, DatabaseValueConvertible {
        let id: ClusteringManager.PageID
        let url: URL
        let title: String

        /// a screenshot of the page's webview when the group is saved.
        var snapshot: Data?
    }
}

// MARK: - BeamObject Conformance
extension TabGroupBeamObject: BeamObjectProtocol {
    static var beamObjectType: BeamObjectObjectType {
        BeamObjectObjectType.tabGroup
    }

    static func == (lhs: TabGroupBeamObject, rhs: TabGroupBeamObject) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.color == rhs.color && lhs.pages == rhs.pages
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(color)
        hasher.combine(pages)
    }

    var beamObjectId: UUID {
        get { id }
        set { id = newValue }
    }

    enum CodingKeys: String, CodingKey {
        case title
        case color
        case pages
        case isLocked
        case parentGroup
        case createdAt
        case updatedAt
        case deletedAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        let codableColor = try values.decode(TabGroupingColor.CodableColor.self, forKey: .color)
        color = TabGroupingColor(designColor: .init(rawValue: codableColor.colorName ?? ""), randomColorHueTint: codableColor.hueTint)
        pages = try values.decode([PageInfo].self, forKey: .pages)
        isLocked = try values.decode(Bool.self, forKey: .isLocked)
        parentGroup = try values.decodeIfPresent(UUID.self, forKey: .parentGroup)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(TabGroupingColor.CodableColor(colorName: color?.designColor?.rawValue, hueTint: color?.randomColorHueTint), forKey: .color)
        try container.encode(pages, forKey: .pages)
        try container.encode(isLocked, forKey: .isLocked)
        if let parentGroup = parentGroup {
            try container.encode(parentGroup, forKey: .parentGroup)
        }
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        if deletedAt != nil {
            try container.encode(deletedAt, forKey: .deletedAt)
        }
    }

    func copy() throws -> TabGroupBeamObject {
        TabGroupBeamObject(id: id, title: title, color: color, pages: pages, isLocked: isLocked,
                           createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt)
    }
}

extension TabGroupBeamObject: TableRecord {
    enum Columns: String, ColumnExpression {
        case id, title, colorName, colorHue, pages, isLocked, parentGroup, createdAt, updatedAt, deletedAt
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
        parentGroup = row[Columns.parentGroup]
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
        container[Columns.parentGroup] = parentGroup
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.deletedAt] = deletedAt
    }
}
