//
//  BrowserTabsManagerUITests.swift
//  BeamUITests
//
//  Created by Stef Kors on 17/06/2021.
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

class BrowserTabsManagerUITests: QuickSpec {
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
    }

    override func spec() {

        describe("Browser Tabs") {
            beforeEach {
                self.manualBeforeTestSuite()
                self.continueAfterFailure = false
                self.journalScrollView = self.app.scrollViews["journalView"]
                self.journalChildren = self.journalScrollView.children(matching: .textView)
                    .matching(identifier: "TextNode")
            }

            it("target=\"_blank\" links open in new tab") {
                self.helper.openTestPage(number: 1)
                let tabsBefore = self.app.images.matching(identifier:"browserTabBarView")
                expect(tabsBefore.count) == 1
                let link = self.app.staticTexts["new-tab-beam"]
                expect(link.waitForExistence(timeout: 10)) == true
                link.click()
                let tabsAfter = self.app.images.matching(identifier:"browserTabBarView")
                expect(tabsAfter.count) == 2
            }
        }
    }
}
