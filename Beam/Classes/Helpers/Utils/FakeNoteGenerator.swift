//
//  FakeNoteGenerator.swift
//  BeamCore
//
//  Created by Sebastien Metrot on 20/07/2021.
//

import Foundation
import BeamCore
import Fakery

class FakeNoteGenerator {
    var notes: [BeamNote] = []
    var count: Int
    var journalRatio: Float
    var futureRatio: Float
    var maxSentencesPerBullet: Int = 5
    var maxRootBullets: Int = 8

    let faker = Faker(locale: "en-US")

    init(count: Int, journalRatio: Float, futureRatio: Float) {
        self.count = count
        self.journalRatio = journalRatio
        self.futureRatio = futureRatio
    }

    var daysRange: Double { Double(count) * 2 }
    var journalCount: Double { Double(count) * Double(journalRatio) }
    var futureCount: Double { journalCount * Double(futureRatio) }
    var pastCount: Double { journalCount - futureCount }
    var firstDay: Date { BeamDate.now.addingTimeInterval(-60 * 60 * 24 * daysRange * (1 - Double(futureRatio))) }

    var randomJournalDate: Date {
        return firstDay.addingTimeInterval(Double.random(in: 0 ..< 60 * 60 * 24 * daysRange))
    }

    var randomJournalNote: BeamNote {
        let date = randomJournalDate
        let note = BeamNote(journalDate: date)
        if date < BeamDate.now {
            note.creationDate = date
        }
        return note
    }

    var randomNormalNote: BeamNote {
        let title = Faker().company.name()
        let note = BeamNote(title: title)
        note.type = .note
        return note
    }

    var randomNote: BeamNote {
        Float.random(in: 0..<1) < journalRatio ? randomJournalNote : randomNormalNote
    }

    var randomLink: BeamText {
        let url = faker.internet.url()
        return BeamText(text: url, attributes: [.link(url)])
    }

    var randomInternalLink: BeamText {
        let index = Int.random(in: 0..<count)
        let note = notes[index]
        let linkId = note.id
        if Float.random(in: 0..<1) < 0.05 {
            return BeamText(text: note.title, attributes: [.internalLink(linkId)])
        }
        return BeamText(text: note.title + " ")
    }

    var randomTextSentence: BeamText {
        BeamText(text: faker.company.bs())
    }

    var randomSentence: BeamText {
        let rand = Float.random(in: 0..<1)
        if rand < 0.8 {
            return randomTextSentence
        } else if rand < 0.9 {
            return randomLink
        }
        return randomInternalLink
    }

    func randomText(length: Int) -> BeamText {
        var text = BeamText()
        for _ in 0..<length {
            text.append(randomSentence)
            text.append(BeamText(text: " "))
        }
        return text
    }

    var randomElement: BeamElement {
        let length = Int.random(in: 0..<maxSentencesPerBullet)
        let text = randomText(length: length)
        let element = BeamElement(text)
        return element
    }

    func randomElementTree(depth: Int) -> BeamElement {
        let element = randomElement
        guard depth <= 6 else { return element }

        let maximum = maxRootBullets / max(depth * depth, 1)
        if maximum > 0 {
            let rootBullets = Int.random(in: 0..<maximum)

            for _ in 0..<rootBullets {
                element.addChild(randomElementTree(depth: depth + 1))
            }
        }
        return element
    }

    func generateNotes() {
        notes = []
        for _ in 0..<count {
            let note = randomNote
            notes.append(note)
            Logger.shared.logDebug("created fake note '\(note.title)'", category: .documentDebug)
        }

        for note in notes {
            let rootBullets = Int.random(in: 0..<maxRootBullets)
            for _ in 0..<rootBullets {
                note.addChild(randomElementTree(depth: 0))
            }
            Logger.shared.logDebug("filled fake note '\(note.title)' with random junk", category: .documentDebug)
        }
    }
}
