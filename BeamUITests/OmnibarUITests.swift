import Foundation
import XCTest
import Quick
import Nimble

class OmniBarUITestsQuick: QuickSpec {
    let app = XCUIApplication()
    var textField: XCUIElement!
    var helper: BeamUITestsHelper!

    //swiftlint:disable:next function_body_length
    override func spec() {
        let textInput = "Hello World"
        let textEmpty = ""

        func inputHasFocus() -> Bool {
            return self.textField.value(forKey: "hasKeyboardFocus") as? Bool ?? false
        }

        beforeSuite {
            self.app.launch()
            self.helper = BeamUITestsHelper(self.app)
        }

        beforeEach {
            self.continueAfterFailure = false
            self.app.launch()
            self.textField = self.app.searchFields["OmniBarSearchField"]
        }

        describe("Search Field") {
            afterEach {
                self.helper.makeElementScreenShot(self.textField)
            }

            it("is focused") {//
                expect(self.textField.exists).to(beTrue())
                expect(inputHasFocus()).to(beTrue())
            }

            it("has user input") {
                self.textField.typeText(textInput)
                expect(self.textField.value as? String).to(equal(textInput))
            }
        }

            describe("Pivot") {

                it("can toggle between web and note") {
                    self.textField.typeText("beam app")
                    self.textField.typeText("\r")
                    expect(self.app.images["browserTabBarView"].waitForExistence(timeout: 2)).to(beTrue())

                    let numberOfResults = self.app.staticTexts.matching(identifier: "autocompleteResult-beam app").count
                    expect(numberOfResults) == 0

                    expect(self.app.groups["webView"].exists).to(beTrue())
                    expect(self.app.buttons["journal"].exists).to(beTrue())
                    expect(self.app.buttons["refresh"].exists).to(beTrue())
                    expect(self.app.buttons["goBack"].exists).to(beTrue())
                    expect(self.app.buttons["pivot-card"].exists).to(beTrue())

                    self.app.buttons["pivot-card"].click()
                    expect(self.app.scrollViews["noteView"].exists).to(beTrue())
                    expect(self.app.buttons["refresh"].exists).to(beFalse())

                    self.app.buttons["pivot-web"].click()
                    expect(self.app.groups["webView"].exists).to(beTrue())
                    expect(self.app.buttons["refresh"].exists).to(beTrue())

                    self.helper.makeAppScreenShots()
                }
            }

        describe("Query") {
            var selectAll: XCUIElement!
            beforeEach {
                selectAll = XCUIApplication().menuItems["Select All"]
            }
            afterEach {
                self.helper.makeElementScreenShot(self.textField)
            }

            it("has textField") { expect(self.textField.exists).to(beTrue()) }

            context("with user input") {
                beforeEach {
                    self.textField.typeText(textInput)
                }

                it("deletes whole input") {
                    expect(self.textField.value as? String).to(equal(textInput))

                    selectAll.tap()
                    self.textField.typeText(XCUIKeyboardKey.delete.rawValue)
                    expect(self.textField.value as? String).to(equal(textEmpty))
                }

                it("deletes chars") {
                    self.textField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
                    let startIndex = textInput.index(textInput.startIndex, offsetBy: 0)
                    let endIndex = textInput.index(textInput.endIndex, offsetBy: -3)
                    let subString = String(textInput[startIndex...endIndex])
                    expect(self.textField.value as? String).to(equal(subString))
                }
            }

            context("without user input") {
                it("doesn't change input") {
                    expect(self.textField.value as? String).to(equal(textEmpty))

                    selectAll.tap()
                    self.textField.typeText(XCUIKeyboardKey.delete.rawValue)
                    expect(self.textField.value as? String).to(equal(textEmpty))
                }
            }
        }

        describe("Autocomplete") {
            let textInput = "beam app"
            let resultPredicate = NSPredicate(format: "identifier CONTAINS 'autocompleteResult'")
            let selectedPredicate = NSPredicate(format: "identifier CONTAINS '-selected'")

            it("displays results") {
                self.textField.typeText(textInput)
                let numberOfResults = self.app.staticTexts.matching(resultPredicate)
                expect(numberOfResults.count) > 0
                expect(numberOfResults.matching(selectedPredicate).count) == 0
                expect(inputHasFocus()).to(beTrue())
            }

            it("echap clears the field") {
                self.textField.typeText(textInput)
                expect(inputHasFocus()).to(beTrue())
                let numberOfResults = self.app.staticTexts.matching(resultPredicate)
                expect(numberOfResults.count) > 0

                // 1st esc clean autocomlete
                self.textField.typeKey(.escape, modifierFlags: .function)
                expect(inputHasFocus()).to(beTrue())
                expect(numberOfResults.count) == 0

                // 2nd esc clear the field
                self.textField.typeKey(.escape, modifierFlags: .function)
                expect(inputHasFocus()).to(beTrue())
                expect(self.textField.value as? String).to(equal(""))

                // 3rd esc unfocus the field
                self.textField.typeKey(.escape, modifierFlags: .function)
                expect(inputHasFocus()).to(beFalse())
            }

            it("can be navigated") {
                self.textField.typeText(textInput)
                // Selected 1st result
                self.textField.typeKey(.downArrow, modifierFlags: .function)
                let selectedResultQuery = self.app.staticTexts.matching(resultPredicate).matching(selectedPredicate)
                expect(selectedResultQuery.count) == 1

                // Go back to input field
                self.textField.typeKey(.upArrow, modifierFlags: .function)
                expect(selectedResultQuery.count) == 0
                expect(inputHasFocus()).to(beTrue())
            }


            it("go to web on enter") {
                self.textField.typeText(textInput)
                self.textField.typeText("\r")
                expect(self.app.images["browserTabBarView"].waitForExistence(timeout: 2)).to(beTrue())
                expect(inputHasFocus()).to(beFalse())

                let numberOfResults = self.app.staticTexts.matching(resultPredicate)
                expect(numberOfResults.count) == 0

                expect(self.app.groups["webView"].exists).to(beTrue())

                self.textField.tap()
                expect(inputHasFocus()).to(beTrue())
                self.textField.typeText("beam desktop")
                expect(numberOfResults.count) > 2
                for _ in 0...2 {
                    self.textField.typeKey(.downArrow, modifierFlags: .function)
                }
                self.textField.typeText("\r")
                expect(numberOfResults.count) == 0
                expect(inputHasFocus()).to(beFalse())
            }

            it("create note and search note") {
                // we're about to create a note, let's clean the DB
                self.helper.tapCommand(.destroyDB)
                // Can be removed when destroying the DB changes the app window
                self.helper.restart()

                self.textField.typeText("Autocomplete Note Creation")
                let createNoteResult = self.app.staticTexts.matching(resultPredicate).matching(NSPredicate(format: "identifier CONTAINS '-createCard'")).firstMatch
                expect(createNoteResult.exists).to(beTrue())
                self.textField.typeKey(.upArrow, modifierFlags: .function)
                self.textField.typeText("\r")

                expect(self.app.scrollViews["noteView"].exists).to(beTrue())
                expect(inputHasFocus()).to(beFalse())

                let journalButton = self.app.buttons["journal"]
                journalButton.tap()

                self.textField.tap()
                self.textField.typeText("Autocomplete Not")
                let noteResults = self.app.staticTexts.matching(resultPredicate).matching(NSPredicate(format: "identifier CONTAINS '-note'"))
                expect(noteResults.firstMatch.waitForExistence(timeout: 2)).to(beTrue())
            }

        }
    }
}
