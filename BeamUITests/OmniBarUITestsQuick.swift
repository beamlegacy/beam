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

        beforeSuite {
            self.helper = BeamUITestsHelper(self.app)
        }

        beforeEach {
            self.continueAfterFailure = false
            self.app.launch()
            self.textField = self.app.textFields["OmniBarSearchField"]
        }

        describe("Omnibar") {
            afterEach {
                self.helper.makeElementScreenShot(self.textField)
            }

            it("is focused") {
                let hasKeyboardFocus = self.textField.value(forKey: "hasKeyboardFocus") as? Bool

                expect(self.textField.exists).to(beTrue())
                expect(hasKeyboardFocus).to(beTrue())
            }

            it("has user input") {
                self.textField.typeText(textInput)
                expect(self.textField.value as? String).to(equal(textInput))
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

        describe("AutoComplete") {
            var autocomplete: XCUIElement!
            let textInput = "beam app"
            beforeEach {
                self.textField.typeText(textInput)
                autocomplete = self.app.scrollViews["autoCompleteView"]
            }

            it("exists") {
                expect(autocomplete.exists).to(beTrue())
            }

            it("can be navigated") {
                self.textField.typeKey(.downArrow, modifierFlags: .function)
                expect(self.app.staticTexts["selected"].exists).to(beTrue())
            }

            it("switches to web mode on enter") {
                for _ in 0...3 {
                    self.textField.typeKey(.downArrow, modifierFlags: .function)
                }

                self.textField.typeText("\r")
                expect(self.app.images["browserTabBarView"].waitForExistence(timeout: 2)).to(beTrue())

                expect(self.app.groups["webView"].exists).to(beTrue())
                expect(self.app.buttons["journal"].exists).to(beTrue())
                expect(self.app.buttons["refresh"].exists).to(beTrue())
                expect(self.app.buttons["goBack"].exists).to(beTrue())
                expect(self.app.buttons["pivot-card"].exists).to(beTrue())

                self.app.buttons["pivot-card"].click()
                expect(self.app.scrollViews["noteView"].exists).to(beTrue())

                self.app.buttons["pivot-web"].click()
                expect(self.app.groups["webView"].exists).to(beTrue())

                self.helper.makeAppScreenShots()
            }
        }
    }
}
