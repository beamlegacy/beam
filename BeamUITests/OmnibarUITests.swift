import Foundation
import XCTest
import Quick
import Nimble

class OmniBarUITestsHelper : BeamUITestsHelper {
    let searchField: XCUIElement
    let autocompleteResultPredicate = NSPredicate(format: "identifier CONTAINS 'autocompleteResult'")
    let autocompleteSelectedPredicate = NSPredicate(format: "identifier CONTAINS '-selected'")
    let autocompleteCreateCardPredicate = NSPredicate(format: "identifier CONTAINS '-createCard'")

    let allAutocompleteResults: XCUIElementQuery

    override init(_ app: XCUIApplication) {
        searchField = app.searchFields["OmniBarSearchField"]
        allAutocompleteResults = app.otherElements.matching(self.autocompleteResultPredicate)
        super.init(app)
    }

    func cleanupDB() {
        self.tapCommand(.logout)
        self.tapCommand(.destroyDB)
    }

    func focusSearchField() {
        self.searchField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func inputHasFocus(_ input: XCUIElement) -> Bool {
        return input.value(forKey: "hasKeyboardFocus") as? Bool ?? false
    }

    func navigateTo(text: String) {
        XCUIApplication().menuItems["Open Location"].tap()
        self.searchField.typeText(text)
        self.searchField.typeText("\r")
    }
}

class OmniBarUITests: QuickSpec {
    let app = XCUIApplication()
    var helper: OmniBarUITestsHelper!

    func manualBeforeSuite () {
        // QuickSpec beforeSuite is called before ALL
        // this is called only before all test of this test class.
        guard self.helper == nil else {
            return
        }
        self.app.launch()
        self.helper = OmniBarUITestsHelper(self.app)
    }


    //swiftlint:disable:next function_body_length
    override func spec() {
        let textInputDumb = "Hello World"
        let textEmpty = ""

        beforeEach {
            self.manualBeforeSuite()
            self.continueAfterFailure = false
            self.app.launch()
        }

        describe("Search Field") {

            let selectAll = XCUIApplication().menuItems["Select All"]

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
                    selectAll.tap()
                    self.helper.searchField.typeText(XCUIKeyboardKey.delete.rawValue)
                    expect(self.helper.searchField.value as? String).to(equal(textEmpty))
                }
            }

            context("without user input") {
                it("deleting all doesnt change input") {
                    expect(self.helper.searchField.value as? String).to(equal(textEmpty))
                    selectAll.tap()
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
                self.helper.searchField.typeText("hello")
                self.helper.searchField.typeText("\r")
                expect(self.app.images["browserTabBarView"].waitForExistence(timeout: 2)).to(beTrue())

                expect(self.helper.allAutocompleteResults.count).to(equal(0))

                expect(self.app.groups["webView"].exists).to(beTrue())
                expect(self.app.buttons["journal"].exists).to(beTrue())
                expect(self.app.buttons["refresh"].exists).to(beTrue())
                expect(self.app.buttons["pivot-card"].exists).to(beTrue())

                self.app.buttons["pivot-card"].tap()
                expect(self.app.scrollViews["noteView"].exists).to(beTrue())
                expect(self.app.buttons["refresh"].exists).to(beFalse())

                self.app.buttons["pivot-web"].tap()
                expect(self.app.groups["webView"].exists).to(beTrue())
                expect(self.app.buttons["refresh"].exists).to(beTrue())

                self.helper.makeAppScreenShots()
            }
        }
    }
}
