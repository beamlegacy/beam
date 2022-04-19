//
//  NoteScoreTest.swift
//  BeamCoreTests
//
//  Created by Paul Lefkopoulos on 07/04/2022.
//

import XCTest
@testable import BeamCore

class NoteScoreTest: XCTestCase {

    func testLocalDailyScores() throws {
        let noteIds = [UUID(), UUID()]
        BeamDate.freeze("2020-01-01T00:00:00+000")
        let scorer = NoteScorer()
        //score insertion
        XCTAssertNil(scorer.getLocalDailyScore(noteId: noteIds[0], daysAgo: 0))
        let wordCounts = [5, 1, 7, 2]
        for wordCount in wordCounts {
            scorer.updateWordCount(noteId: noteIds[0], wordCount: wordCount)
        }
        var score0 = try XCTUnwrap(scorer.getLocalDailyScore(noteId: noteIds[0], daysAgo: 0))
        XCTAssertEqual(score0.minWordCount, 1)
        XCTAssertEqual(score0.maxWordCount, 7)
        XCTAssertEqual(score0.firstWordCount, 5)
        XCTAssertEqual(score0.lastWordCount, 2)
        XCTAssertEqual(score0.addedBidiLinkToCount, 0)
        XCTAssertEqual(score0.visitCount, 0)
        XCTAssertEqual(score0.captureToCount, 0)
        scorer.incrementVisitCount(noteId: noteIds[0])
        scorer.incrementVisitCount(noteId: noteIds[1]) //be sure there is no interference between notes
        scorer.incrementCaptureToCount(noteId: noteIds[0])
        scorer.incrementBidiLinkToCount(noteId: noteIds[0])
        score0 = try XCTUnwrap(scorer.getLocalDailyScore(noteId: noteIds[0], daysAgo: 0))
        XCTAssertEqual(score0.addedBidiLinkToCount, 1)
        XCTAssertEqual(score0.visitCount, 1)
        XCTAssertEqual(score0.captureToCount, 1)

        //a new day gets it's own daily score
        BeamDate.travel(24 * 60 * 60)
        XCTAssertNil(scorer.getLocalDailyScore(noteId: noteIds[0], daysAgo: 0))
        scorer.incrementVisitCount(noteId: noteIds[0])
        XCTAssertNotNil(scorer.getLocalDailyScore(noteId: noteIds[0], daysAgo: 0))

        //cleanup removes older scores
        scorer.cleanup(daysToKeep: 1)
        XCTAssertNil(scorer.getLocalDailyScore(noteId: noteIds[0], daysAgo: 1))
        XCTAssertNotNil(scorer.getLocalDailyScore(noteId: noteIds[0], daysAgo: 0))
        BeamDate.reset()
    }

    func testWordCountScoreUpdate() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")

        let note = BeamNote(title: "Animals")
        let elements = [
            BeamElement("Grey dog"),
            BeamElement("Tall green cow"),
            BeamElement("Ostrich")
        ]
        note.addChild(elements[0])
        var score = try XCTUnwrap(NoteScorer.shared.getLocalDailyScore(noteId: note.id, daysAgo: 0))
        XCTAssertEqual(score.lastWordCount, 2)
        elements[0].addChild(elements[1])
        score = try XCTUnwrap(NoteScorer.shared.getLocalDailyScore(noteId: note.id, daysAgo: 0))
        XCTAssertEqual(score.lastWordCount, 5)
        note.addChild(elements[2])
        score = try XCTUnwrap(NoteScorer.shared.getLocalDailyScore(noteId: note.id, daysAgo: 0))
        XCTAssertEqual(score.lastWordCount, 6)
        elements[1].text = BeamText("Tall green")
        score = try XCTUnwrap(NoteScorer.shared.getLocalDailyScore(noteId: note.id, daysAgo: 0))
        XCTAssertEqual(score.lastWordCount, 5)
        note.removeChild(elements[2])
        score = try XCTUnwrap(NoteScorer.shared.getLocalDailyScore(noteId: note.id, daysAgo: 0))
        XCTAssertEqual(score.lastWordCount, 4)
        BeamDate.reset()
    }
}
