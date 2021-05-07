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
                self.helper.typeInSearchAndWait(textInputSearch)
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
                self.helper.searchField.typeKey(.escape, modifierFlags: [])
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
                expect(results.count).to(equal(0))

                // 2nd esc clear the field
                self.helper.searchField.typeKey(.escape, modifierFlags: [])
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
                expect(self.helper.searchField.value as? String).to(equal(""))

                // 3rd esc unfocus the field
                self.helper.searchField.typeKey(.escape, modifierFlags: [])
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beFalse())
            }

            it("can be navigated") {
                self.helper.focusSearchField()
                self.helper.typeInSearchAndWait("Testing navigation")
                // Selected 1st result
                self.helper.searchField.typeKey(.downArrow, modifierFlags: [])
                let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
                expect(selectedResultQuery.count).to(equal(1))

                // Go back to input field
                self.helper.searchField.typeKey(.upArrow, modifierFlags: [])
                expect(selectedResultQuery.count).to(equal(0))
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
            }


            it("can go to web on enter") {
                self.helper.typeInSearchAndWait(textInputSearch)
                self.helper.searchField.typeKey(.enter, modifierFlags: [])
                expect(self.app.images["browserTabBarView"].waitForExistence(timeout: 2)).to(beTrue())
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beFalse())

                let results = self.helper.allAutocompleteResults
                expect(results.count).to(equal(0))

                expect(self.app.groups["webView"].exists).to(beTrue())

                self.helper.focusSearchField()
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
                self.helper.typeInSearchAndWait("hello world")
                expect(results.count) > 2
                for _ in 0...2 {
                    self.helper.searchField.typeKey(.downArrow, modifierFlags: [])
                }
                self.helper.searchField.typeKey(.enter, modifierFlags: [])
                expect(results.count).to(equal(0))
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beFalse())
            }

            it("can create and search note") {
                self.helper.focusSearchField()
                self.helper.typeInSearchAndWait("Autocomplete Note Creation")
                let createNoteResult = self.helper.allAutocompleteResults.matching(self.helper.autocompleteCreateCardPredicate).firstMatch
                expect(createNoteResult.exists).to(beTrue())
                createNoteResult.tapInTheMiddle()

                expect(self.app.scrollViews["noteView"].waitForExistence(timeout: 2)).to(beTrue())
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beFalse())
                sleep(1) // wait for new note to be saved
                
                let journalButton = self.app.buttons["journal"]
                journalButton.tap()

                self.helper.focusSearchField()
                self.helper.typeInSearchAndWait("Autocomplete Not")
                let noteResults = self.helper.allAutocompleteResults.matching(NSPredicate(format: "identifier CONTAINS '-note'"))
                expect(noteResults.firstMatch.waitForExistence(timeout: 2)).to(beTrue())
            }

            it("can press cmd+enter to create note") {
                self.helper.typeInSearchAndWait("Command Enter Note")
                let createNoteResult = self.helper.allAutocompleteResults.matching(self.helper.autocompleteCreateCardPredicate).firstMatch
                expect(createNoteResult.exists).to(beTrue())
                XCUIElement.perform(withKeyModifiers: .command) {
                    let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
                    expect(selectedResultQuery.count) == 1
                }
                self.helper.searchField.typeKey("\r", modifierFlags: .command)
                expect(self.app.scrollViews["noteView"].waitForExistence(timeout: 2)).to(beTrue())
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beFalse())
            }

            context("automatic result selection") {

                it("handle selection") {
                    self.helper.searchField.typeText("fr.wikipedia.org/wiki/Hello_world")
                    self.helper.searchField.typeKey(.enter, modifierFlags: [])
                    expect(self.app.images["browserTabBarView"].waitForExistence(timeout: 2)) == true

                    self.helper.focusSearchField()
                    expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())

                    // Start Typing
                    self.helper.searchField.typeText("Hel")
                    let results = self.helper.allAutocompleteResults
                    expect(results.count) > 1
                    let firstResult = results.firstMatch
                    let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
                    let expectedIdentifier = "autocompleteResult-selected-Hello world-history"
                    expect(firstResult.identifier) == expectedIdentifier
                    expect(self.helper.searchField.value as? String) == "Hello world"

                    // Adding 1 letter, keep selection
                    self.helper.searchField.typeText("l")
                    expect(firstResult.identifier) == expectedIdentifier
                    expect(self.helper.searchField.value as? String) == "Hello world"

                    // Adding other letter, clear selection
                    self.helper.searchField.typeText("a")
                    expect(self.helper.searchField.value as? String) == "Hella"
                    expect(selectedResultQuery.count) == 0

                    // Testing the selected range in the search text
                    self.helper.searchField.typeKey(.delete, modifierFlags: [])
                    self.helper.searchField.typeKey(.delete, modifierFlags: [])

                    // re-select
                    self.helper.searchField.typeText("l")
                    expect(selectedResultQuery.count) == 1
                    expect(self.helper.searchField.value as? String) == "Hello world"

                    // clear the selected text cancel selection
                    self.helper.searchField.typeKey(.delete, modifierFlags: [])
                    self.helper.searchField.typeKey(.delete, modifierFlags: [])
                    expect(selectedResultQuery.count) == 0
                    expect(self.helper.searchField.value as? String) == "Hel"

                    // re-select again
                    self.helper.searchField.typeText("l")
                    expect(selectedResultQuery.count) == 1
                    expect(self.helper.searchField.value as? String) == "Hello world"

                    // moving at end of selection
                    self.helper.searchField.typeKey(.rightArrow, modifierFlags: [])
                    expect(selectedResultQuery.count) == 0
                    self.helper.searchField.typeText("s")
                    expect(self.helper.searchField.value as? String) == "Hello worlds"
                }

                it("typing fast") {
                    self.helper.searchField.typeText("en.wikipedia.org/wiki/Hubert_Blaine_Wolfeschlegelsteinhausenbergerdorff_Sr.")
                    self.helper.searchField.typeKey(.enter, modifierFlags: [])
                    expect(self.app.images["browserTabBarView"].waitForExistence(timeout: 2)) == true
                    expect(self.helper.inputHasFocus(self.helper.searchField)) == false

                    self.helper.focusSearchField()
                    expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())

                    // Start Typing
                    let title = "Hubert Blaine Wolfeschlegelsteinhausenbergerdorff Sr."
                    let typed = title.lowercased().substring(from: 0, to: title.count - 6)
                    self.helper.searchField.typeSlowly(typed, everyNChar: 5)

                    let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
                    expect(self.helper.searchField.value as? String) == typed + title.substring(from: typed.count, to: title.count)
                    expect(selectedResultQuery.count) == 1
                }

            }
        }
    }
}
