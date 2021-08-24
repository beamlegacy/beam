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
        self.helper.cleanupDB(logout: true)
    }

    var tabbarView: XCUIElement {
        self.app.groups["browserTabBarView"]
    }

    
    //swiftlint:disable:next function_body_length
    override func spec() {

        beforeEach {
            self.manualBeforeTestSuite()
            self.continueAfterFailure = false
        }

        afterEach {
            self.helper.makeAppScreenShots()
        }

        describe("Keyboard Usage") {

            beforeEach {
                self.app.launch()
            }

            it("displays results") {
                self.helper.typeInSearchAndWait(self.helper.randomSearchTerm())
                let results = self.helper.allAutocompleteResults
                expect(results.count) > 0
                expect(results.matching(self.helper.autocompleteSelectedPredicate).count).to(equal(0))
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
            }

            it("can escape to clear searchfield") {
                self.helper.searchField.typeText("Testing escape key")
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
                let results = self.helper.allAutocompleteResults
                expect(results.firstMatch.waitForExistence(timeout: 1)) == true
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
                self.helper.typeInSearchAndWait(self.helper.randomSearchTerm())
                self.helper.searchField.typeKey(.enter, modifierFlags: [])
                expect(self.tabbarView.waitForExistence(timeout: 2)).to(beTrue())
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beFalse())

                let results = self.helper.allAutocompleteResults
                expect(results.count).to(equal(0))

                expect(self.app.webViews.firstMatch.exists).to(beTrue())
            }

            //            Google sometimes doesn't return results in the CI, so this test was failing randomly
            //            We should look at it and see if we can make a reliable test for a random api
            //            https://linear.app/beamapp/issue/BE-929/google-search-doesnt-return-results-sometimes
            //            it("should show google results") {
            //                self.helper.focusSearchField()
            //                self.helper.typeInSearchAndWait(self.helper.randomSearchTerm())
            //                let results = self.helper.allAutocompleteResults
            //                let googleResults = results.matching(NSPredicate(format: "identifier CONTAINS '-autocomplete'"))
            //                expect(googleResults.firstMatch.waitForExistence(timeout: 2)) == true
            //                expect(results.count) > 2
            //                expect(googleResults.count) > 1
            //                for _ in 0...2 {
            //                    self.helper.searchField.typeKey(.downArrow, modifierFlags: [])
            //                }
            //                self.helper.searchField.typeKey(.enter, modifierFlags: [])
            //                expect(results.count) == 0
            //                expect(self.helper.inputHasFocus(self.helper.searchField)) == false
            //            }
        }

        describe("Note Usage") {
            beforeEach {
                self.app.launch()
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
        }

        describe("Automatic Selection") {
            var hasLaunchedForThisContext = false
            beforeEach {
                if !hasLaunchedForThisContext {
                    hasLaunchedForThisContext = true
                    self.app.launch()
                    self.helper.cleanupDB(logout: false)
                    self.helper.tapCommand(.omnibarFillHistory)
                }
                // focus and clear search field
                self.helper.focusSearchField()
                self.helper.searchField.typeKey("a", modifierFlags: .command)
                self.helper.searchField.typeKey(.delete, modifierFlags: .function)
            }

            it("handles title search") {
                // Start Typing
                self.helper.typeInSearchAndWait("Hel")
                let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
                expect(selectedResultQuery.firstMatch.waitForExistence(timeout: 10)) == true

                let results = self.helper.allAutocompleteResults
                let firstResult = results.firstMatch
                let expectedIdentifier = "autocompleteResult-selected-Hello world-history"
                expect(firstResult.identifier) == expectedIdentifier
                expect(self.helper.searchField.value as? String) == "Hello world"

                // Adding 1 letter, keep selection
                self.helper.typeInSearchAndWait("l")
                expect(firstResult.identifier) == expectedIdentifier
                expect(self.helper.searchField.value as? String) == "Hello world"

                // Adding other letter, clear selection
                self.helper.typeInSearchAndWait("a")
                expect(self.helper.searchField.value as? String) == "Hella"
                expect(selectedResultQuery.count) == 0

                // Testing the selected range in the search text
                self.helper.searchField.typeKey(.delete, modifierFlags: [])
                self.helper.searchField.typeKey(.delete, modifierFlags: [])

                // re-select
                self.helper.typeInSearchAndWait("l")
                expect(selectedResultQuery.count) == 1
                expect(self.helper.searchField.value as? String) == "Hello world"

                // clear the selected text cancel selection
                self.helper.searchField.typeKey(.delete, modifierFlags: [])
                self.helper.searchField.typeKey(.delete, modifierFlags: [])
                expect(selectedResultQuery.count) == 0
                expect(self.helper.searchField.value as? String) == "Hel"

                // re-select again
                self.helper.typeInSearchAndWait("l")
                expect(selectedResultQuery.count) == 1
                expect(self.helper.searchField.value as? String) == "Hello world"

                // moving at end of selection
                self.helper.searchField.typeKey(.rightArrow, modifierFlags: [])
                expect(selectedResultQuery.count) == 0
                self.helper.typeInSearchAndWait("s")
                expect(self.helper.searchField.value as? String) == "Hello worlds"
            }

            it("handles URL search") {
                // Start Typing
                self.helper.typeInSearchAndWait("fr.wiki")
                let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
                expect(selectedResultQuery.firstMatch.waitForExistence(timeout: 10)) == true

                let results = self.helper.allAutocompleteResults
                let firstResult = results.firstMatch
                let expectedIdentifier = "autocompleteResult-selected-fr.wikipedia.org/wiki/Hello_world-url"
                expect(firstResult.identifier) == expectedIdentifier
                expect(self.helper.searchField.value as? String) == "fr.wikipedia.org/wiki/Hello_world"

                // Adding 1 letter, keep selection
                self.helper.typeInSearchAndWait("p")
                expect(firstResult.identifier) == expectedIdentifier
                expect(self.helper.searchField.value as? String) == "fr.wikipedia.org/wiki/Hello_world"

                // Adding other letter, clear selection
                self.helper.typeInSearchAndWait("a")
                expect(self.helper.searchField.value as? String) == "fr.wikipa"
                expect(selectedResultQuery.count) == 0

                // clear the selected text cancel selection
                self.helper.searchField.typeKey(.delete, modifierFlags: [])
                expect(self.helper.searchField.value as? String) == "fr.wikip"
                expect(selectedResultQuery.count) == 0

                // re-select again
                self.helper.typeInSearchAndWait("e")
                expect(firstResult.identifier) == expectedIdentifier
                expect(self.helper.searchField.value as? String) == "fr.wikipedia.org/wiki/Hello_world"
                expect(selectedResultQuery.count) == 1

                // moving at end of selection
                self.helper.searchField.typeKey(.rightArrow, modifierFlags: [])
                expect(selectedResultQuery.count) == 0
                self.helper.typeInSearchAndWait("s")
                expect(self.helper.searchField.value as? String) == "fr.wikipedia.org/wiki/Hello_worlds"
            }

            it("handles typing title fast") {
                // Start Typing
                let title = "Hubert Blaine Wolfeschlegelsteinhausenbergerdorff Sr."
                self.helper.typeInSearchAndWait("hub")
                let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
                expect(selectedResultQuery.firstMatch.waitForExistence(timeout: 10)) == true

                // Type the rest of the character progressively
                let endTypingAtIndex = title.count - 6
                let typed = title.lowercased().substring(from: 3, to: endTypingAtIndex)
                self.helper.searchField.typeSlowly(typed, everyNChar: 5)

                expect(self.helper.searchField.value as? String) == title.lowercased().substring(from: 0, to: endTypingAtIndex) + title.substring(from: endTypingAtIndex, to: title.count)
                expect(selectedResultQuery.count) == 1
            }

        }
    }
}
