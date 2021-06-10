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

private let RUN_PNS_TEST = false

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
        
        let titles = [
            "Point And Shoot Test Fixture - Ultralight Beam",
            "Point And Shoot Test Fixture - I-Beam",
            "Point And Shoot Test Fixture - Cursor"
        ]

        describe("Navigating to web") {
            beforeEach {
                self.manualBeforeTestSuite()
                self.helper.tapCommand(.destroyDB)
                self.continueAfterFailure = false
                self.app.launch()
                self.journalScrollView = self.app.scrollViews["journalView"]
                self.journalChildren = self.journalScrollView.children(matching: .textView)
                    .matching(identifier: "TextNode")
            }
            
            it("add links to journal in order") {
                self.helper.openTestPage(number: 1)
                let title0 = titles[0]
                let staticText0 = self.app.staticTexts[title0]
                expect(staticText0.waitForExistence(timeout: 10)) == true
                self.helper.showJournal()
                expect(self.journalChildren.element(matching: NSPredicate(format: "value = %@", title0)).firstMatch.waitForExistence(timeout: 2)) == true
                expect(self.journalChildren.element(boundBy: 0).value as? String) == title0

                self.helper.openTestPage(number: 2)
                let title1 = titles[1]
                let staticText1 = self.app.staticTexts[title1]
                expect(staticText1.waitForExistence(timeout: 10)) == true
                self.helper.showJournal()
                expect(self.journalChildren.element(matching: NSPredicate(format: "value = %@", title1)).firstMatch.waitForExistence(timeout: 2)) == true
                expect(self.journalChildren.element(boundBy: 0).value as? String) == title0
                expect(self.journalChildren.element(boundBy: 1).value as? String) == title1

                self.helper.openTestPage(number: 3)
                let title2 = titles[2]
                expect(self.app.staticTexts[title2].waitForExistence(timeout: 10)) == true
                self.helper.showJournal()
                expect(self.journalChildren.element(matching: NSPredicate(format: "value = %@", title2)).firstMatch.waitForExistence(timeout: 2)) == true
                expect(self.journalChildren.element(boundBy: 0).value as? String) == title0
                expect(self.journalChildren.element(boundBy: 1).value as? String) == title1
                expect(self.journalChildren.element(boundBy: 2).value as? String) == title2
            }

            it("can navigate links in collected text") {
                self.helper.openTestPage(number: 3)

                let searchText = "Go to "
                let linkText = "Cincinati Zoo"

                // Get locations of the text
                let parent = self.app.webViews.containing(.staticText, identifier: searchText).element
                let textElement = parent.staticTexts[searchText]
                _ = textElement.coordinate(withNormalizedOffset: CGVector(dx: -0.2, dy: 0.5))
                let textElementMiddle = textElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                // click at middle of element1 to make sure the page has focus
                textElementMiddle.click()
                // Hold option
                XCUIElement.perform(withKeyModifiers: .option) {
                    // While holding option
                    // 1 point frame should be visible
                    let shootSelections = self.app.otherElements.matching(identifier:"PointFrame")
                    expect(shootSelections.count) == 1
                    // Clicking element to trigger shooting mode
                    textElementMiddle.click()
                    // Release option
                }

                // Add to today's note
                self.helper.addNote()
                // Confirm text is saved in Journal
                self.helper.showJournal()
                let title2Predicate = NSPredicate(format: "value = %@", titles[2])
                expect(self.journalChildren.element(matching: title2Predicate).waitForExistence(timeout: 4)) == true
                expect(self.journalChildren.count) == 2
                expect(self.journalChildren.element(boundBy: 0).value as? String) == titles[2]
                expect((self.journalChildren.element(boundBy: 1).value as? String)?.contains(linkText)) == true
                // tap on collected sublink (end of new bullet)
                let linkCoordinate = self.journalChildren.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.24, dy: 0.5))
                linkCoordinate.click()
                // tap on a link in the page, should be added to opened bullet
                let lionLink = self.app.webViews.staticTexts["California sea lions"].firstMatch
                expect(lionLink.waitForExistence(timeout: 4)) == true
                lionLink.tap()
                self.helper.showJournal()
                let seaLionLink = "California sea lion - Wikipedia"
                let seaLionPredicate = NSPredicate(format: "value = %@", seaLionLink)
                expect(self.journalChildren.element(matching: seaLionPredicate).waitForExistence(timeout: 4)) == true
                expect(self.journalChildren.count) == 3
                expect(self.journalChildren.element(boundBy: 2).value as? String) == seaLionLink
            }
        }

        context("PNS") {
            guard RUN_PNS_TEST else { return }

            beforeEach {
                self.manualBeforeTestSuite()
                self.helper.tapCommand(.destroyDB)
                self.continueAfterFailure = false
                self.app.launch()
                self.journalScrollView = self.app.scrollViews["journalView"]
                self.journalChildren = self.journalScrollView.children(matching: .textView)
                    .matching(identifier: "TextNode")
                self.helper.tapCommand(.resizeWindowLandscape)
            }
            describe("Shoot") {
                it("dismiss shootCardPicker by clicking on page and pressing escape") {
                    self.helper.openTestPage(number: 1)
                    let searchText = "Ultralight Beam, Kanye West"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // click and drag between start and end of full text
                    let child = parent.staticTexts[searchText]
                    let start = child.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.1))
                    let end = child.coordinate(withNormalizedOffset: CGVector(dx: 1.1, dy: 0.9))
                    start.click(forDuration: 1, thenDragTo: end)
                    
                    // Press option once to enable shoot mode
                    XCUIElement.perform(withKeyModifiers: .option) {}
                    
                    let shootSelections = self.app.otherElements.matching(identifier:"ShootFrameSelection")
                    expect(shootSelections.count) == 1
                    
                    let emptyLocation = child.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -1))
                    emptyLocation.click()
                    sleep(1)
                    let shootSelections2 = self.app.otherElements.matching(identifier:"ShootFrameSelection")
                    expect(shootSelections2.count) == 0

                    start.click(forDuration: 1, thenDragTo: end)

                    // Press option once to enable shoot mode
                    XCUIElement.perform(withKeyModifiers: .option) {}

                    let shootSelections3 = self.app.otherElements.matching(identifier:"ShootFrameSelection")
                    expect(shootSelections3.count) == 1

                    // dismiss shootCardPicker with escape
                    self.app.typeKey(.escape, modifierFlags: [])

                    let shootSelections4 = self.app.otherElements.matching(identifier:"ShootFrameSelection")
                    expect(shootSelections4.count) == 0
                }
            }
            describe("Select") {
                it("frame position placement") {
                    self.helper.openTestPage(number: 1)
                    let searchText = "Ultralight Beam, Kanye West"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // click and drag between start and end of full text
                    let child = parent.staticTexts[searchText]
                    let start = child.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.1))
                    let end = child.coordinate(withNormalizedOffset: CGVector(dx: 1.1, dy: 0.9))
                    start.click(forDuration: 1, thenDragTo: end)
                    
                    // Press option once to enable shoot mode
                    XCUIElement.perform(withKeyModifiers: .option) {
                        sleep(1)
                    }
                    
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    // Zoom in
                    self.app.typeKey("+", modifierFlags: .command)
                    self.app.typeKey("+", modifierFlags: .command)
                    self.app.typeKey("+", modifierFlags: .command)
                    
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    // Zoom out
                    self.app.typeKey("-", modifierFlags: .command)
                    self.app.typeKey("-", modifierFlags: .command)
                    self.app.typeKey("-", modifierFlags: .command)
                    
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    // Scroll page
                    self.app.webViews.firstMatch.scroll(byDeltaX: 0, deltaY: -200)
                    
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    // Resize window
                    self.helper.tapCommand(.resizeWindowPortrait)
                    
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    // Add to today's note
                    self.helper.addNote()
                    
                    // After shooting then pressing and releasing option shouldn't keep pointframe active
                    XCUIElement.perform(withKeyModifiers: .option) {
                        sleep(1)
                    }
                    
                    let pointFrames = self.app.otherElements.matching(identifier:"PointFrame")
                    expect(pointFrames.count) == 0
                }
            }
                
            describe("Point") {
                it("frame position placement") {
                    self.helper.openTestPage(number: 1)
                    let searchText = "Ultralight Beam, Kanye West"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    let child = parent.staticTexts[searchText]
                    let center = child.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    // click at middle of searchText to focus on page
                    center.click()
                    
                    // Hold option to enable point mode
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        center.hover()
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Zoom in
                        self.app.typeKey("+", modifierFlags: .command)
                        self.app.typeKey("+", modifierFlags: .command)
                        self.app.typeKey("+", modifierFlags: .command)
                        
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Zoom out
                        self.app.typeKey("-", modifierFlags: .command)
                        self.app.typeKey("-", modifierFlags: .command)
                        self.app.typeKey("-", modifierFlags: .command)
                        
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Scroll page
                        self.app.webViews.firstMatch.scroll(byDeltaX: 0, deltaY: -200)

                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Resize window
                        self.helper.tapCommand(.resizeWindowPortrait)
                        center.hover()

                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Shoot
                        center.click()
                        // Release option
                    }
                    
                    let pointFrames = self.app.otherElements.matching(identifier:"PointFrame")
                    expect(pointFrames.count) == 0
                    
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    
                    // Add to today's note
                    let noteTitle = "Ultralight Beam"
                    self.helper.addNote(noteTitle: noteTitle)
                    
                    // Assert card association
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option, hover text
                        center.hover()
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        
                        let ShootFrameSelectionLabel = self.app.staticTexts.matching(identifier: "ShootFrameSelectionLabel").element
                        let shootValue = ShootFrameSelectionLabel.value as! String
                        expect(shootValue) == noteTitle
                    }
                }
            }
        }
    }
}
