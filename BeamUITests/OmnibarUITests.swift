import Foundation
import XCTest
#if canImport(Quick)
import Quick
#endif
#if canImport(Nimble)
import Nimble
#endif

class OmniBarUITests: QuickSpec {
    let app = XCUIApplication()
    var helper: OmniBarUITestsHelper!

    func manualBeforeSuite () {
        // QuickSpec beforeSuite is called before ALL
        // this is called only before all test of this test class.
        guard self.helper == nil else {
            return
        }
        self.helper = OmniBarUITestsHelper(self.app)
    }

    func selectAllShorcut() {
        self.helper.searchField.typeKey("a", modifierFlags: .command)
    }

    //swiftlint:disable:next function_body_length
    override func spec() {
        let textInputDumb = "Hello World"
        let textEmpty = ""

        beforeEach {
            self.app.launch()
            self.manualBeforeSuite()
            self.continueAfterFailure = false
        }

        describe("Search Field") {

            afterEach {
                self.helper.makeElementScreenShot(self.helper.searchField)
            }

            it("is focused on launch") {
                expect(self.helper.searchField.exists).to(beTrue())
                expect(self.helper.inputHasFocus(self.helper.searchField)).to(beTrue())
            }

            it("can handle user input") {
                self.helper.searchField.typeText(textInputDumb)
                expect(self.helper.searchField.value as? String).to(equal(textInputDumb))
            }

            context("with user input") {
                beforeEach {
                    self.helper.searchField.typeText(textInputDumb)
                }

                it("can delete chars") {
                    self.helper.searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
                    let startIndex = textInputDumb.index(textInputDumb.startIndex, offsetBy: 0)
                    let endIndex = textInputDumb.index(textInputDumb.endIndex, offsetBy: -3)
                    let subString = String(textInputDumb[startIndex...endIndex])
                    expect(self.helper.searchField.value as? String).to(equal(subString))
                }

                it("can delete whole input") {
                    expect(self.helper.searchField.value as? String).to(equal(textInputDumb))
                    self.selectAllShorcut()
                    self.helper.searchField.typeText(XCUIKeyboardKey.delete.rawValue)
                    expect(self.helper.searchField.value as? String).to(equal(textEmpty))
                }
            }

            context("without user input") {
                it("deleting all doesnt change input") {
                    expect(self.helper.searchField.value as? String).to(equal(textEmpty))
                    self.selectAllShorcut()
                    self.helper.searchField.typeText(XCUIKeyboardKey.delete.rawValue)
                    expect(self.helper.searchField.value as? String).to(equal(textEmpty))
                }
            }
        }

        describe("Pivot Button") {

            afterEach {
                self.helper.makeAppScreenShots()
            }

            it("can toggle web and note") {
                self.helper.focusSearchField()
                self.helper.searchField.typeText("hello")
                self.helper.searchField.typeText("\r")
                expect(self.app.images["browserTabBarView"].waitForExistence(timeout: 1)).to(beTrue())

                expect(self.helper.allAutocompleteResults.count).to(equal(0))
                expect(self.app.buttons["journal"].exists).to(beTrue())
                expect(self.app.buttons["refresh"].exists).to(beTrue())
                expect(self.app.buttons["pivot-card"].exists).to(beTrue())

                self.app.buttons["pivot-card"].tap()
                expect(self.app.scrollViews["noteView"].exists).to(beTrue())
                expect(self.app.buttons["refresh"].exists).to(beFalse())

                self.app.buttons["pivot-web"].tap()
                expect(self.app.webViews.firstMatch.waitForExistence(timeout: 1)).to(beTrue())
                expect(self.app.buttons["refresh"].exists).to(beTrue())

                self.helper.makeAppScreenShots()
            }
        }
    }
}
