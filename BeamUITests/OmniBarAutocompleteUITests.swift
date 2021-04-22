//
//  OmniBarAutocompleteUITests.swift
//  BeamUITests
//
//  Created by Remi Santos on 10/03/2021.
//

import Foundation
import XCTest
#if canImport(Quick)
import Quick
#endif
#if canImport(Nimble)
import Nimble
#endif

class OmniBarAutocompleteUITests: QuickSpec {
    let app = XCUIApplication()
    var helper: OmniBarUITestsHelper!

    func manualBeforeTestSuite () {
        // QuickSpec beforeSuite is called before ALL
        // this is called only before all test of this test class.
        guard self.helper == nil else {
            return
        }
        self.app.launch()
        self.helper = OmniBarUITestsHelper(self.app)
        self.helper.cleanupDB()
    }


    //swiftlint:disable:next function_body_length
    override func spec() {

        let textInputSearch = "hello"

        beforeEach {
            self.manualBeforeTestSuite()
            self.continueAfterFailure = false
            self.app.launch()
        }

        afterEach {
            self.helper.makeAppScreenShots()
        }


        describe("Autocomplete") {

            it("displays results") {
                self.helper.searchField.typeText(textInputSearch)
                let results = self.helper.allAutocompleteResults
                expect(results.count) > 0
                expect(results.matching(self.helper.autocompleteSelectedPredicate).count).to(equal(0))
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
            }

            it("can escape to clear searchfield") {
                self.helper.searchField.typeText("Testing escape key")
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
                let results = self.helper.allAutocompleteResults
                expect(results.count) > 0

                // 1st esc clean autocomlete
                self.helper.searchField.typeKey(.escape, modifierFlags: .function)
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
                expect(results.count).to(equal(0))

                // 2nd esc clear the field
                self.helper.searchField.typeKey(.escape, modifierFlags: .function)
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
                expect(self.helper.searchField.value as? String).to(equal(""))

                // 3rd esc unfocus the field
                self.helper.searchField.typeKey(.escape, modifierFlags: .function)
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beFalse())
            }

            it("can be navigated") {
                self.helper.focusSearchField()
                self.helper.searchField.typeText("Testing navigation")
                // Selected 1st result
                self.helper.searchField.typeKey(.downArrow, modifierFlags: .function)
                let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
                expect(selectedResultQuery.count).to(equal(1))

                // Go back to input field
                self.helper.searchField.typeKey(.upArrow, modifierFlags: .function)
                expect(selectedResultQuery.count).to(equal(0))
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
            }


            it("can go to web on enter") {
                self.helper.searchField.typeText(textInputSearch)
                self.helper.searchField.typeText("\r")
                expect(self.app.images["browserTabBarView"].waitForExistence(timeout: 2)).to(beTrue())
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beFalse())

                let results = self.helper.allAutocompleteResults
                expect(results.count).to(equal(0))

                expect(self.app.groups["webView"].exists).to(beTrue())

                self.helper.focusSearchField()
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
                self.helper.searchField.typeText("hello world")
                expect(results.count) > 2
                for _ in 0...2 {
                    self.helper.searchField.typeKey(.downArrow, modifierFlags: .function)
                }
                self.helper.searchField.typeText("\r")
                expect(results.count).to(equal(0))
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beFalse())
            }

            it("can create and search note") {
                self.helper.restart()

                self.helper.searchField.typeText("Autocomplete Note Creation")
                let createNoteResult = self.helper.allAutocompleteResults.matching(self.helper.autocompleteCreateCardPredicate).firstMatch
                expect(createNoteResult.exists).to(beTrue())
                createNoteResult.tap()

                expect(self.app.scrollViews["noteView"].waitForExistence(timeout: 2)).to(beTrue())
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beFalse())
                sleep(1) // wait for new note to be saved
                
                let journalButton = self.app.buttons["journal"]
                journalButton.tap()

                self.helper.focusSearchField()
                self.helper.searchField.typeText("Autocomplete Not")
                let noteResults = self.helper.allAutocompleteResults.matching(NSPredicate(format: "identifier CONTAINS '-note'"))
                expect(noteResults.firstMatch.waitForExistence(timeout: 2)).to(beTrue())
            }

            it("can press cmd+enter to create note") {
                self.helper.searchField.typeText("Command Enter Note")
                let createNoteResult = self.helper.allAutocompleteResults.matching(self.helper.autocompleteCreateCardPredicate).firstMatch
                expect(createNoteResult.exists).to(beTrue())
                self.helper.searchField.typeKey("\r", modifierFlags: XCUIElement.KeyModifierFlags.command)

                expect(self.app.scrollViews["noteView"].waitForExistence(timeout: 2)).to(beTrue())
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beFalse())
            }

        }
    }
}
