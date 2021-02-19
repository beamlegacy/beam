//
//  JournalUITests.swift
//  BeamUITests
//
//  Created by Jean-Louis Darmon on 08/02/2021.
//

import Foundation
import XCTest
#if canImport(Quick)
import Quick
#endif
#if canImport(Nimble)
import Nimble
#endif

class JournalUITests: QuickSpec {
    let app = XCUIApplication()
    var journalScrollView: XCUIElement!

    // swiftlint:disable:next function_body_length
    override func spec() {
        beforeEach {
            self.continueAfterFailure = false
            self.app.launch()
            self.journalScrollView = self.app.scrollViews["journalView"]
        }

        describe("Journal scrolling") {
            afterEach {
                for _ in 0...10 {
                    self.journalScrollView.scroll(byDeltaX: 0, deltaY: -1000)
                }
            }
            context("without any data") {
                beforeEach {
                    var destroyDb: XCUIElement!
                    destroyDb = XCUIApplication().menuItems["Destroy DB"]
                    destroyDb.tap()
                    self.app.terminate()
                    self.app.launch()
                }

                it("has a scrollView") {
                    expect(self.journalScrollView.exists).to(beTrue())
                }
            }
            context("with a few days of data") {
                beforeEach {
                    var prepareApp: XCUIElement!
                    prepareApp = XCUIApplication().menuItems["Populate DB"]
                    prepareApp.tap()
                    self.app.terminate()
                    self.app.launch()
                }
                it("has a scrollView") {
                    expect(self.journalScrollView.exists).to(beTrue())
                }
            }
        }
    }
}
