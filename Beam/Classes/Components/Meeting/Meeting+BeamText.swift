//
//  Meeting+BeamText.swift
//  Beam
//
//  Created by Remi Santos on 08/10/2021.
//

import Foundation
import BeamCore

extension Meeting: BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    func buildBeamText() -> BeamText {
        var text = BeamText(text: "")
        var meetingAttributes: [BeamText.Attribute] = []
        if self.linkCards {
            guard let meetingNote = try? BeamNote.fetchOrCreate(self, title: self.name) else { return text }
            meetingAttributes = [.internalLink(meetingNote.id)]
        }
        text.insert(self.name, at: 0, withAttributes: meetingAttributes)

        if !self.attendees.isEmpty {
            let prefix = "Meeting with "
            var position = prefix.count
            text.insert(prefix, at: 0, withAttributes: [])
            self.attendees.enumerated().forEach { index, attendee in
                let name = attendee.name
                guard let attendeeNote = try? BeamNote.fetchOrCreate(self, title: name) else { return }
                text.insert(name, at: position, withAttributes: [.internalLink(attendeeNote.id)])
                position += name.count
                if index < self.attendees.count - 1 {
                    let separator = ", "
                    text.insert(separator, at: position, withAttributes: [])
                    position += separator.count
                }
            }
            text.insert(" for ", at: position, withAttributes: [])
        }
        return text
    }
}
