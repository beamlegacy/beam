//
//  NoteDailySummaryTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 12/04/2022.
//

import XCTest
@testable import Beam
@testable import BeamCore

class NoteDailySummaryTest: XCTestCase, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    override func setUpWithError() throws {
        BeamTestsHelper.logout()
    }

    override func tearDownWithError() throws {
        try BeamData.shared.currentDocumentCollection?.delete(self, filters: [])
    }

    func testGetSummary() throws {
        guard let collection = BeamData.shared.currentDocumentCollection else { throw BeamDataError.databaseNotFound }
        let cal = Calendar(identifier: .iso8601)
        BeamDate.freeze("2001-01-01T00:01:00+000")
        let now = BeamDate.now
        let dates = (0...2).map { cal.date(byAdding: .day, value: -$0, to: now)! }
        var docs = try (0...5).map { _ -> BeamDocument in
            let id = UUID()
            return try collection.fetchOrCreate(self, id: id, type: .note(title: id.uuidString))
        }
        //updated 2 days ago
        docs[0].updatedAt = dates[2]
        //updated one day ago but created before
        docs[1].updatedAt = dates[1]
        docs[1].createdAt = dates[2]
        docs[5].updatedAt = dates[1]
        docs[5].createdAt = dates[2]
        //created one day ago
        docs[2].createdAt = dates[1]
        docs[2].updatedAt = dates[0]
        docs[3].createdAt = dates[1]
        docs[3].updatedAt = dates[0]
        //created today
        docs[4].updatedAt = dates[0]

        for doc in docs {
            _ = try collection.save(self, doc, indexDocument: true)
        }

        let store = InMemoryDailyNoteScoreStore()
        let scorer = NoteScorer(dailyStorage: store)

        //adding a score for yesterday
        BeamDate.freeze("2000-12-31T00:01:00+000")
        scorer.incrementCaptureToCount(noteId: docs[2].id)
        scorer.updateWordCount(noteId: docs[2].id, wordCount: 10)
        scorer.updateWordCount(noteId: docs[2].id, wordCount: 11)

        scorer.updateWordCount(noteId: docs[1].id, wordCount: 10)
        scorer.updateWordCount(noteId: docs[1].id, wordCount: 11)

        //stable wordcount but was created during period of interest
        scorer.updateWordCount(noteId: docs[3].id, wordCount: 10)
        scorer.updateWordCount(noteId: docs[3].id, wordCount: 10)

        //stable wordcount only updated during period of interest wont appear
        scorer.updateWordCount(noteId: docs[5].id, wordCount: 10)
        scorer.updateWordCount(noteId: docs[5].id, wordCount: 10)
        let summary = NoteDailySummary(dailyScoreStore: store)

        //fetching scored docs today for the day before
        BeamDate.freeze("2001-01-01T00:01:00+000")
        let scoredDocuments = try summary.get()
        XCTAssertEqual(scoredDocuments.count, 3)

        XCTAssertEqual(scoredDocuments[0].noteId, docs[2].id)
        XCTAssert(scoredDocuments[0].created)
        XCTAssertNotNil(scoredDocuments[0].score)
        XCTAssertEqual(scoredDocuments[0].captureToCount, 1)

        XCTAssertEqual(scoredDocuments[1].noteId, docs[1].id)
        XCTAssertFalse(scoredDocuments[1].created)
        XCTAssertNotNil(scoredDocuments[1].score)
        XCTAssertEqual(scoredDocuments[1].captureToCount, 0)

        BeamDate.reset()
    }
}
