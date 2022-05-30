//
//  AccountCalendar.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 21/12/2021.
//

import Foundation

class AccountCalendar: Identifiable {
    var id: UUID = UUID()
    var sourceId: UUID
    var service: CalendarServices
    var name: String
    var nbrOfCalendar: Int
    var meetingCalendar: [MeetingCalendar]?

    init(sourceId: UUID, service: CalendarServices, name: String, nbrOfCalendar: Int, meetingCalendar: [MeetingCalendar]? = nil) {
        self.sourceId = sourceId
        self.service = service
        self.name = name
        self.nbrOfCalendar = nbrOfCalendar
        self.meetingCalendar = meetingCalendar
    }
}
