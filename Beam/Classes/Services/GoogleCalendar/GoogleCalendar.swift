//
//  GoogleCalendar.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 04/10/2021.
//

import Foundation

class GoogleAccount: Codable {
    var email: String
}

class GoogleCalendarList: Codable {
    let calendars: [GoogleCalendar]

    enum CodingKeys: String, CodingKey {
        case calendars = "items"
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        calendars = try container.decode([GoogleCalendar].self, forKey: .calendars)
    }
}

class GoogleCalendar: Codable {
    var id: String
    var summary: String
    var description: String?

    init(id: String, summary: String, description: String?) {
        self.id = id
        self.summary = summary
        self.description = description
    }
}
