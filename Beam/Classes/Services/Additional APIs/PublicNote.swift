//
//  PublicNote.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 20/09/2021.
//

import Foundation
import BeamCore

struct PublicNote: Encodable {

    var note: BeamNote
    var tabGroups: [TabGroupBeamObject]?

    enum CodingKeys: String, CodingKey {
        case title
        case type
        case isPublic = "is_public"
        case data
        case creationDate = "created_at"
        case updateDate = "updated_at"
        case databaseId = "database_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(note.title, forKey: .title)
        if note.type == .note {
            try container.encode("note", forKey: .type)
        }
        try container.encode(encodedData(), forKey: .data)
        try container.encode(note.creationDate, forKey: .creationDate)
        try container.encode(note.updateDate, forKey: .updateDate)
        try container.encode(note.databaseId, forKey: .databaseId)
    }

    private func encodedData() -> String? {
        let encoder = JSONEncoder()
        let noteObject = NoteObjectForPublicAPI(note: note, tabGroups: tabGroups)
        guard let data = try? encoder.encode(noteObject) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private struct NoteObjectForPublicAPI: Encodable {
    let note: BeamNote
    let tabGroups: [TabGroupBeamObject]?

    enum AdditionalCodingKeys: String, CodingKey {
        case tabGroups
    }

    public func encode(to encoder: Encoder) throws {
        try note.encode(to: encoder)
        var container = encoder.container(keyedBy: AdditionalCodingKeys.self)
        if let tabGroups = tabGroups {
            let tabGroupsAsDictionary = Dictionary(uniqueKeysWithValues: tabGroups.map {
                ($0.id.uuidString, PublicAPITabGroup(with: $0))
            })
            try container.encode(tabGroupsAsDictionary, forKey: .tabGroups)
        }
    }
}

private struct PublicAPITabGroup: Encodable {
    var title: String?
    var colorName: String?
    var colorHue: String?
    var pages: [TabGroupBeamObject.PageInfo]

    init(with tabGroup: TabGroupBeamObject) {

        title = tabGroup.title
        pages = Self.pagesWithoutSnapshot(tabGroup.pages)
        colorName = tabGroup.color?.designColor?.id
        if colorName == nil, let hue = tabGroup.color?.randomColorHueTint {
            colorHue = "\(hue)"
        }
    }

    private static func pagesWithoutSnapshot(_ pages: [TabGroupBeamObject.PageInfo]) -> [TabGroupBeamObject.PageInfo] {
        return pages.map { page in
            var page = page
            page.snapshot = nil
            return page
        }
    }

    enum CodingKeys: String, CodingKey {
        case title
        case pages
        case colorName = "color_name"
        case colorHue = "color_hue"
    }
}
