//
//  NavigationCollectUITests.swift
//  BeamUITests
//
//  Created by Remi Santos on 20/04/2021.
//

import Foundation
import XCTest
#if canImport(Quick)
import Quick
#endif
#if canImport(Nimble)
import Nimble
#endif
import BeamCore

class NavigationCollectUITests: QuickSpec {
    let app = XCUIApplication()
    var helper: BeamUITestsHelper!
    var omnibarHelper: OmniBarUITestsHelper!
    var journalScrollView: XCUIElement!
    var journalChildren: XCUIElementQuery!

    func manualBeforeTestSuite () {
        // QuickSpec beforeSuite is called before ALL
        // this is called only before all test of this test class.
        guard self.helper == nil else {
            return
        }
        self.app.launch()
        self.helper = BeamUITestsHelper(self.app)
        self.omnibarHelper = OmniBarUITestsHelper(self.app)
        self.helper.tapCommand(.logout)
    }

    override func spec() {

        beforeEach {
            self.manualBeforeTestSuite()
            self.helper.tapCommand(.destroyDB)
            self.continueAfterFailure = false
            self.app.launch()
            self.journalScrollView = self.app.scrollViews["journalView"]
            self.journalChildren = self.journalScrollView.children(matching: .textView)
                .matching(identifier: "TextNode")
        }

        describe("Navigating to web") {
            let urls = [
                "en.wikipedia.org/wiki/Red_panda",
                "en.wikipedia.org/wiki/Giant_panda",
                "en.wikipedia.org/wiki/Kung_Fu_Panda"
            ]
            let titles = [
                "Red panda - Wikipedia",
                "Giant panda - Wikipedia",
                "Kung Fu Panda - Wikipedia"
            ]

            it("add links to journal in order") {
                self.omnibarHelper.navigateTo(text: urls[0])
                self.helper.showJournal()
                expect(self.journalChildren.count) == 1
                expect(self.journalChildren.element(boundBy: 0).value as? String) == titles[0]

                self.omnibarHelper.navigateTo(text: urls[1])
                self.helper.showJournal()
                expect(self.journalChildren.count) == 2
                expect(self.journalChildren.element(boundBy: 0).value as? String) == titles[0]
                expect(self.journalChildren.element(boundBy: 1).value as? String) == titles[1]

                self.omnibarHelper.navigateTo(text: urls[2])
                self.helper.showJournal()
                expect(self.journalChildren.count) == 3
                expect(self.journalChildren.element(boundBy: 0).value as? String) == titles[0]
                expect(self.journalChildren.element(boundBy: 1).value as? String) == titles[1]
                expect(self.journalChildren.element(boundBy: 2).value as? String) == titles[2]
            }

            it("can select text and add to note") {
                self.omnibarHelper.navigateTo(text: urls[0])
                // Selecting the "A red panda at the [Cincinnati Zoo]" string,
                // which is composed of two elements, text and then link.
                // Great exemple of complex selction.
                let searchText = "A red panda at the "
                let linkText = "Cincinnati Zoo"
                let fullText = searchText + linkText
                let parent = self.app.webViews.firstMatch.tables.cells.containing(.staticText,
                                                                                  identifier: searchText).element

                // click and drag between start and end of full text
                let firstChild = parent.staticTexts[searchText]
                let secondChild = parent.staticTexts[linkText]
                let start = firstChild.coordinate(withNormalizedOffset: CGVector(dx: -0.2, dy: 0.5))
                let end = secondChild.coordinate(withNormalizedOffset: CGVector(dx: 1.1, dy: 0.5))
                start.click(forDuration: 1, thenDragTo: end)

                // Add to today's note
                let notePickerField = self.app.textFields["Today"].firstMatch
                expect(notePickerField.waitForExistence(timeout: 2)) == true
                notePickerField.typeText("\r")

                self.helper.showJournal()
                expect(self.journalChildren.count) == 2
                expect(self.journalChildren.element(boundBy: 0).value as? String) == titles[0]
                // There's a bug where the selected text looses the first few characters
                // once fixed we should remove the substring part
                let substring = fullText.substring(range: 7..<fullText.count)
                expect((self.journalChildren.element(boundBy: 1).value as? String)?.contains(substring)) == true

                // tap on collected sublink (end of new bullet)
                let linkCoordinate = self.journalChildren.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
                linkCoordinate.click()

                // tap on a link in the page, should be added to opened bullet
                let lionLink = self.app.webViews.staticTexts["California sea lions"].firstMatch
                expect(lionLink.waitForExistence(timeout: 2)) == true
                lionLink.tap()
                self.helper.showJournal()
                expect(self.journalChildren.count) == 3
                expect(self.journalChildren.element(boundBy: 2).value as? String) == "California sea lion - Wikipedia"
            }
        }
    }
}
