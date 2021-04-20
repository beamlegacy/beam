//
//  OmniBarDestinationUITests.swift
//  BeamUITests
//
//  Created by Remi Santos on 10/03/2021.
//

import Foundation
import XCTest
import Quick
import Nimble

class OmniBarDestinationUITests: QuickSpec {
    let app = XCUIApplication()
    var helper: OmniBarUITestsHelper!
    let destinationNoteTitle = "One Destination"

    func manualBeforeSuite () {
        // QuickSpec beforeSuite is called before ALL
        // this is called only before all test of this test class.
        guard self.helper == nil else {
            return
        }
        self.app.launch()
        self.helper = OmniBarUITestsHelper(self.app)
        self.helper.cleanupDB()
        createDestinationNote()
    }

    func createDestinationNote() {
        self.helper.searchField.typeText(destinationNoteTitle)
        let createNoteResult = self.helper.allAutocompleteResults.matching(NSPredicate(format: "identifier CONTAINS '-createCard'")).firstMatch
        createNoteResult.tap()
        sleep(1) // wait for new note to be saved
        let journalButton = self.app.buttons["journal"]
        journalButton.tap()
    }

    
    //swiftlint:disable:next function_body_length
    override func spec() {

        let noteSearchField = self.app.searchFields["DestinationNoteSearchField"]
        let todayName = "Today"

        func goToWebMode() {
            self.helper.searchField.typeText("hello world")
            self.helper.searchField.typeText("\r")
        }

        beforeEach {
            self.manualBeforeSuite()
            self.continueAfterFailure = false
            self.app.launch()
        }

        afterEach {
            self.helper.makeAppScreenShots()
        }

        describe("Destination Note") {

            it("displays 'today' by default") {
                goToWebMode()
                let title = self.app.staticTexts["DestinationNoteTitle"]
                expect(title.waitForExistence(timeout: 2)).to(beTrue())
                title.tap()
                expect(noteSearchField.waitForExistence(timeout: 2)).to(beTrue())
                expect(self.helper.inputHasFocus(noteSearchField)).to(beTrue())
                expect(noteSearchField.value as? String).to(equal(""))
                expect(noteSearchField.placeholderValue).to(equal(todayName))
                let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
                expect(selectedResultQuery.count).to(equal(1))
            }

            it("can be focused with shortcut") {
                goToWebMode()
                let title = self.app.staticTexts["DestinationNoteTitle"]
                expect(title.waitForExistence(timeout: 2)).to(beTrue())

                let menuItem = XCUIApplication().menuItems["Change Card"]
                menuItem.tap()

                expect(self.helper.inputHasFocus(noteSearchField)).to(beTrue())
                expect(noteSearchField.value as? String).to(equal(""))
                expect(noteSearchField.placeholderValue).to(equal(todayName))
                let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
                expect(selectedResultQuery.count).to(equal(1))
            }

            it("can be navigated") {
                goToWebMode()

                let title = self.app.staticTexts["DestinationNoteTitle"]
                expect(title.waitForExistence(timeout: 2)).to(beTrue())
                title.tap()

                expect(noteSearchField.waitForExistence(timeout: 2)).to(beTrue())
                expect(self.helper.inputHasFocus(noteSearchField)).to(beTrue())

                // down arrow
                let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
                let firstResult = selectedResultQuery.firstMatch.identifier
                noteSearchField.typeKey(.downArrow, modifierFlags: .function)
                let secondResult = selectedResultQuery.firstMatch.identifier
                expect(secondResult).toNot(equal(firstResult))

                // up arrow
                noteSearchField.typeKey(.upArrow, modifierFlags: .function)
                let thirdResult = selectedResultQuery.firstMatch.identifier
                expect(thirdResult).to(equal(firstResult))

                // escape
                noteSearchField.typeKey(.escape, modifierFlags: .function)
                expect(self.helper.inputHasFocus(noteSearchField)).to(beFalse())
                expect(title.exists).to(beTrue())
            }

            it("can select note and pivot") {
                goToWebMode()

                let title = self.app.staticTexts["DestinationNoteTitle"]
                expect(title.waitForExistence(timeout: 2)).to(beTrue())
                expect(title.value as? String).to(equal(todayName))
                title.tap()

                noteSearchField.typeText("One")
                noteSearchField.typeText("\r")
                expect(title.value as? String).to(equal(self.destinationNoteTitle))

                expect(self.app.buttons["pivot-card"].exists).to(beTrue())
                self.app.buttons["pivot-card"].tap()

                expect(self.app.scrollViews["noteView"].exists).to(beTrue())
                expect(title.exists).to(beFalse())

                expect(self.app.buttons["pivot-web"].exists).to(beTrue())
                self.app.buttons["pivot-web"].tap()
                expect(title.exists).to(beTrue())
                expect(title.value as? String).to(equal(self.destinationNoteTitle))
                title.tap()
                expect(noteSearchField.waitForExistence(timeout: 2)).to(beTrue())
                expect(noteSearchField.value as? String).to(equal(self.destinationNoteTitle))
            }

            it("can create note and pivot") {
                goToWebMode()

                let secondTitle = "Seond Destination"
                let title = self.app.staticTexts["DestinationNoteTitle"]
                expect(title.waitForExistence(timeout: 2)).to(beTrue())
                expect(title.value as? String).to(equal(todayName))
                title.tap()

                noteSearchField.typeText(secondTitle)
                let createNoteItem = self.app.staticTexts.matching(NSPredicate(format: "identifier CONTAINS 'autocompleteResult'")).matching(NSPredicate(format: "identifier CONTAINS '-createCard'")).firstMatch
                expect(createNoteItem.exists).to(beTrue())
                noteSearchField.typeText("\r")
                expect(title.value as? String).to(equal(secondTitle))

                expect(self.app.buttons["pivot-card"].exists).to(beTrue())
                self.app.buttons["pivot-card"].tap()

                expect(self.app.scrollViews["noteView"].exists).to(beTrue())
                expect(title.exists).to(beFalse())

                expect(self.app.buttons["pivot-web"].exists).to(beTrue())
                self.app.buttons["pivot-web"].tap()
                expect(title.exists).to(beTrue())
                expect(title.value as? String).to(equal(secondTitle))
                title.tap()
                expect(noteSearchField.waitForExistence(timeout: 2)).to(beTrue())
                expect(noteSearchField.value as? String).to(equal(secondTitle))
            }
        }
    }
}
