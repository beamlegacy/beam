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
    var helper: BeamUITestsHelper!

    // swiftlint:disable:next function_body_length
    override func spec() {
        beforeSuite {
            self.helper = BeamUITestsHelper(self.app)
        }
        beforeEach {
            self.continueAfterFailure = false
            self.app.launch()
            self.helper.tapCommand(.logout)
            self.journalScrollView = self.app.scrollViews["journalView"]
        }

        afterEach {
            self.helper.makeAppScreenShots()
        }

        describe("Journal scrolling") {
            afterEach {
                for _ in 0...10 {
                    self.journalScrollView.scroll(byDeltaX: 0, deltaY: -1000)
                }
            }
            context("without any data") {
                beforeEach {
                    self.helper.tapCommand(.destroyDB)
                    // Can be removed when destroying the DB changes the app window
                    self.helper.restart()
                }

                it("has a scrollView") {
                    expect(self.journalScrollView.exists) == true
                }
            }
            context("with a few days of data") {
                beforeEach {
                    self.helper.tapCommand(.populateDBWithJournal)
                    // Can be removed when destroying the DB changes the app window
                    self.helper.restart()
                }

                it("has a scrollView") {
                    expect(self.journalScrollView.exists) == true
                }
            }
        }
    }
}
