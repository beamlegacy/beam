//
//  TabGroup.swift
//  Beam
//
//  Created by Remi Santos on 12/07/2022.
//

import Foundation

final class TabGroup: Identifiable {

    typealias GroupID = UUID

    private(set) var id = GroupID()
    private(set) var title: String?
    private(set) var color: TabGroupingColor?
    private(set) var pageIds: [ClusteringManager.PageID]
    private(set) var collapsed = false
    private(set) var isLocked: Bool = false

    /// Whether or not the group has been interacted with by the user and should therefore be persisted
    private(set) var shouldBePersisted: Bool = false

    init(id: GroupID = GroupID(), pageIds: [ClusteringManager.PageID],
         title: String? = nil, color: TabGroupingColor? = nil, isLocked: Bool = false) {
        self.id = id
        self.pageIds = pageIds
        self.title = title
        self.color = color
        shouldBePersisted = title?.isEmpty == false
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(GroupID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        let codableColor = try values.decode(TabGroupingColor.CodableColor.self, forKey: .color)
        color = TabGroupingColor(designColor: .init(rawValue: codableColor.colorName ?? ""), randomColorHueTint: codableColor.hueTint)
        pageIds = try values.decode([ClusteringManager.PageID].self, forKey: .pages)
        isLocked = try values.decode(Bool.self, forKey: .isLocked)
    }

    func changeTitle(_ title: String) {
        self.title = title
        shouldBePersisted = !title.isEmpty
    }

    func changeColor(_ color: TabGroupingColor, isInitialColor: Bool = false) {
        self.color = color
        if isInitialColor {
            shouldBePersisted = true
        }
    }

    func updatePageIds(_ pageIds: [ClusteringManager.PageID]) {
        self.pageIds = pageIds
    }

    func toggleCollapsed() {
        collapsed.toggle()
    }

    func copy(locked: Bool = false, discardPages: Bool = true) -> TabGroup {
        let newGroup = TabGroup(pageIds: pageIds)
        newGroup.title = title
        newGroup.color = color
        newGroup.collapsed = collapsed
        newGroup.shouldBePersisted = shouldBePersisted
        newGroup.isLocked = locked
        newGroup.pageIds = discardPages ? [] : pageIds
        return newGroup
    }
}

extension TabGroup: Equatable, Hashable {
    static func == (lhs: TabGroup, rhs: TabGroup) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension TabGroup: Codable {

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case color
        case pages
        case isLocked
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(TabGroupingColor.CodableColor(colorName: color?.designColor?.rawValue, hueTint: color?.randomColorHueTint), forKey: .color)
        try container.encode(pageIds, forKey: .pages)
        try container.encode(isLocked, forKey: .isLocked)
    }
}
