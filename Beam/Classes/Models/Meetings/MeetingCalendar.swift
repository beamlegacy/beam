//
//  MeetingCalendar.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 20/12/2021.
//

import Foundation

class MeetingCalendar {
    var id: String
    var summary: String
    var description: String?

    init(id: String, summary: String, description: String?) {
        self.id = id
        self.summary = summary
        self.description = description
    }
}
