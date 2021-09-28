//
//  DestinationNoteAutocompleteListTests.swift
//  BeamTests
//
//  Created by Stef Kors on 21/09/2021.
//

import XCTest
@testable import Beam
@testable import BeamCore

class DestinationNoteAutocompleteListTests: XCTestCase {
    var autocompleteModel = DestinationNoteAutocompleteList.Model()

    override func setUpWithError() throws {
        self.autocompleteModel.data = BeamData()
    }

    func testGetDateForCardReplacementJournalNote_TodayAsWord() throws {
        let cardName = "Today"
        let result = autocompleteModel.getDateForCardReplacementJournalNote(cardName)
        XCTAssertNotNil(result)
    }

    func testGetDateForCardReplacementJournalNote_TodayAsDateString() throws {
        guard let data = self.autocompleteModel.data else {
            XCTFail("failed to get todaysName from BeamData")
            return
        }
        let cardName = data.todaysName
        let result = autocompleteModel.getDateForCardReplacementJournalNote(cardName)
        XCTAssertNotNil(result)
    }

    func testGetDateForCardReplacementJournalNote_NotMatchingDate() throws {
        let cardName = "1 March 1991" // Launch of Tim's first browser
        let result = autocompleteModel.getDateForCardReplacementJournalNote(cardName)
        XCTAssertNil(result)
    }

    func testGetCardReplacementKeywordDate_TodayAsWord() throws {
        let cardName = "Today"
        let result = autocompleteModel.getCardReplacementKeywordDate(cardName)
        XCTAssertNil(result)
    }

    func testGetCardReplacementKeywordDate_TodayAsDateString() throws {
        guard let data = self.autocompleteModel.data else {
            XCTFail("failed to get todaysName from BeamData")
            return
        }
        let cardName = data.todaysName
        let result = autocompleteModel.getCardReplacementKeywordDate(cardName)
        XCTAssertNotNil(result)
    }

    func testGetCardReplacementKeywordDate_NotMatchingDate() throws {
        let cardName = "1 March 1991" // Launch of Tim's first browser
        let result = autocompleteModel.getCardReplacementKeywordDate(cardName)
        XCTAssertNil(result)
    }

    func testRealNameForCardName_TodayAsWord() throws {
        guard let data = self.autocompleteModel.data else {
            XCTFail("failed to get todaysName from BeamData")
            return
        }
        let cardName = data.todaysName
        let result = autocompleteModel.realNameForCardName(cardName)
        XCTAssertEqual(result, cardName)
    }

    func testRealNameForCardName_Today() throws {
        let cardName = "Today"
        let result = autocompleteModel.realNameForCardName(cardName)
        XCTAssertNotNil(result)
        XCTAssertNotEqual(result, cardName)

        // Assert supporting multiple formats "September 26, 2021" or "26 September 2021"
        let date = Date()
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let month = calendar.monthSymbols[calendar.component(.month, from: date)-1]
        let year = calendar.component(.year, from: date)
        XCTAssertTrue(result.contains("\(day)"))
        XCTAssertTrue(result.contains("\(month)"))
        XCTAssertTrue(result.contains("\(year)"))
    }
}
