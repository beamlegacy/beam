//
//  GoogleEvent.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 04/10/2021.
//

import Foundation

class GoogleEventList: Codable {
    let events: [GoogleEvent]

    enum CodingKeys: String, CodingKey {
        case events = "items"
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        events = try container.decode([GoogleEvent].self, forKey: .events)
    }
}

class GoogleEvent: Codable {
    let id: String
    let summary: String?
    let description: String?
    let startDate: EventDate?
    let endDate: EventDate?
    let attendees: [GoogleEventAttendee]?
    let htmlLink: String?
    let hangoutLink: String?
    let conferenceData: GoogleEventConferenceData?

    enum CodingKeys: String, CodingKey {
        case id
        case summary
        case description
        case startDate = "start"
        case endDate = "end"
        case attendees
        case htmlLink
        case hangoutLink
        case conferenceData
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        summary = try? container.decode(String.self, forKey: .summary)
        description = try? container.decode(String.self, forKey: .description)
        startDate = try? container.decode(EventDate.self, forKey: .startDate)
        endDate = try? container.decode(EventDate.self, forKey: .endDate)
        attendees = try? container.decode([GoogleEventAttendee].self, forKey: .attendees)
        htmlLink = try? container.decode(String.self, forKey: .htmlLink)
        hangoutLink = try? container.decode(String.self, forKey: .hangoutLink)
        conferenceData = try? container.decode(GoogleEventConferenceData.self, forKey: .conferenceData)
    }
}

class EventDate: Codable {
    let date: String?
    let dateTime: String?
    let timeZone: String?
}

class GoogleEventAttendee: Codable {
    let email: String?
    let displayName: String?
    let organizer: Bool?
    let responseStatus: String?
    let isSelf: Bool?

    private enum CodingKeys: String, CodingKey {
        case email, displayName, organizer, responseStatus, isSelf = "self"
    }
}

class GoogleEventConferenceData: Codable {
    let entryPoints: [ConferenceDataEntryPoints]

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entryPoints = try container.decode([ConferenceDataEntryPoints].self, forKey: .entryPoints)
    }
}

class ConferenceDataEntryPoints: Codable {
    let entryPointType: String?
    let uri: String?
    let meetingCode: String?
    let passcode: String?
}
