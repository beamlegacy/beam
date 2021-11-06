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
        try container.encode(encodedNote(), forKey: .data)
        try container.encode(note.creationDate, forKey: .creationDate)
        try container.encode(note.updateDate, forKey: .updateDate)
        try container.encode(note.databaseId, forKey: .databaseId)
    }

    private func encodedNote() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(note) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
