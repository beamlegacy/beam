//
//  NoteDailySummaryTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 12/04/2022.
//

import XCTest
@testable import Beam
@testable import BeamCore

class NoteDailySummaryTest: XCTestCase {
    var sut: DocumentManager!
    var helper: DocumentManagerTestsHelper!


    override func setUpWithError() throws {
        sut = DocumentManager()
        helper = DocumentManagerTestsHelper(documentManager: sut,
                                            coreDataManager: CoreDataManager.shared)
        BeamTestsHelper.logout()    }

    override func tearDownWithError() throws {
        helper.deleteAllDocuments()
    }

    func testSort() {
        let now = BeamDate.now
        let after = now + 10.0

        let scoredDocuments = [
            ScoredDocument(noteId: UUID(), title: "", createdAt: now, updatedAt: now, created: false, score: 0, captureToCount: 0),
            ScoredDocument(noteId: UUID(), title: "", createdAt: now, updatedAt: after, created: false, score: nil, captureToCount: 0),
            ScoredDocument(noteId: UUID(), title: "", createdAt: now, updatedAt: now, created: false, score: nil, captureToCount: 0),
            ScoredDocument(noteId: UUID(), title: "", createdAt: now, updatedAt: now, created: false, score: 10, captureToCount: 0)
        ]
        let sorted = scoredDocuments.sorted(by: <)
        //when score is nil, sorted by updatedAt
        XCTAssertEqual(sorted[0].noteId, scoredDocuments[2].noteId)
        XCTAssertEqual(sorted[1].noteId, scoredDocuments[1].noteId)
        //otherwise sorted by score
        XCTAssertEqual(sorted[2].noteId, scoredDocuments[0].noteId)
        XCTAssertEqual(sorted[3].noteId, scoredDocuments[3].noteId)
    }

    func testGetSummary() throws {
        let cal = Calendar(identifier: .iso8601)
        BeamDate.freeze("2001-01-01T00:01:00+000")
        let now = BeamDate.now
        let dates = (0...2).map { cal.date(byAdding: .day, value: -$0, to: now)! }
        var docStructs = (0...5).map { _ in helper.createDocumentStruct() }
        //updated 2 days ago
        docStructs[0].updatedAt = dates[2]
        //updated one day ago but created before
        docStructs[1].updatedAt = dates[1]
        docStructs[1].createdAt = dates[2]
        docStructs[5].updatedAt = dates[1]
        docStructs[5].createdAt = dates[2]
        //created one day ago
        docStructs[2].createdAt = dates[1]
        docStructs[2].updatedAt = dates[1]
        docStructs[3].createdAt = dates[1]
        docStructs[3].updatedAt = dates[1]
        //created today
        docStructs[4].updatedAt = dates[0]

        for doc in docStructs {
            let expectation = XCTestExpectation()
            sut.save(doc, completion:  { _ in
                expectation.fulfill()
            })
            wait(for: [expectation], timeout: 10.0)
        }
        let store = InMemoryDailyNoteScoreStore()
        let scorer = NoteScorer(dailyStorage: store)

        //adding a score for yesterday
        BeamDate.freeze("2000-12-31T00:01:00+000")
        scorer.incrementCaptureToCount(noteId: docStructs[2].id)
        scorer.updateWordCount(noteId: docStructs[2].id, wordCount: 10)
        scorer.updateWordCount(noteId: docStructs[2].id, wordCount: 11)

        scorer.updateWordCount(noteId: docStructs[1].id, wordCount: 10)
        scorer.updateWordCount(noteId: docStructs[1].id, wordCount: 11)

        //stable wordcount but was created during period of interest
        scorer.updateWordCount(noteId: docStructs[3].id, wordCount: 10)
        scorer.updateWordCount(noteId: docStructs[3].id, wordCount: 10)

        //stable wordcount only updated during period of interest wont appear
        scorer.updateWordCount(noteId: docStructs[5].id, wordCount: 10)
        scorer.updateWordCount(noteId: docStructs[5].id, wordCount: 10)
        let summary = NoteDailySummary(dailyScoreStore: store)

        //fetching scored docs today for the day before
        BeamDate.freeze("2001-01-01T00:01:00+000")
        let scoredDocuments = try summary.get()
        XCTAssertEqual(scoredDocuments.count, 3)

        XCTAssertEqual(scoredDocuments[0].noteId, docStructs[2].id)
        XCTAssert(scoredDocuments[0].created)
        XCTAssertNotNil(scoredDocuments[0].score)
        XCTAssertEqual(scoredDocuments[0].captureToCount, 1)

        XCTAssertEqual(scoredDocuments[1].noteId, docStructs[1].id)
        XCTAssertFalse(scoredDocuments[1].created)
        XCTAssertNotNil(scoredDocuments[1].score)
        XCTAssertEqual(scoredDocuments[1].captureToCount, 0)

        BeamDate.reset()
    }
}
