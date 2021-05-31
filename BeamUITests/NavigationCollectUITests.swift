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
        
        let urls = [
            "en.wikipedia.org/w/index.php?title=Red_panda&oldid=1024738414",
            "en.wikipedia.org/w/index.php?title=Giant_panda&oldid=1025413108",
            "en.wikipedia.org/w/index.php?title=Kung_Fu_Panda&oldid=1024626447",
            "en.wikipedia.org/w/index.php?title=Internet_Explorer&oldid=1025328966",
            "en.wikipedia.org/w/index.php?title=Point-and-shoot_camera&oldid=1022913329",
            "en.wikipedia.org/w/index.php?title=Piranhaconda&oldid=1022691141",
            "text.npr.org/996515792",
            "en.wikipedia.org/w/index.php?title=Netscape&oldid=1024220830"
        ]
        
        let titles = [
            "Red panda - Wikipedia",
            "Giant panda - Wikipedia",
            "Kung Fu Panda - Wikipedia"
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
                self.omnibarHelper.navigateTo(text: urls[0])
                expect(self.app.staticTexts[titles[0]].waitForExistence(timeout: 10)) == true
                self.helper.showJournal()
                expect(self.journalChildren.element(matching: NSPredicate(format: "value = %@", titles[0])).firstMatch.waitForExistence(timeout: 2)) == true
                expect(self.journalChildren.element(boundBy: 0).value as? String) == titles[0]

                self.omnibarHelper.navigateTo(text: urls[1])
                expect(self.app.staticTexts[titles[1]].waitForExistence(timeout: 10)) == true
                self.helper.showJournal()
                expect(self.journalChildren.element(matching: NSPredicate(format: "value = %@", titles[1])).firstMatch.waitForExistence(timeout: 2)) == true
                expect(self.journalChildren.element(boundBy: 0).value as? String) == titles[0]
                expect(self.journalChildren.element(boundBy: 1).value as? String) == titles[1]

                self.omnibarHelper.navigateTo(text: urls[2])
                expect(self.app.staticTexts[titles[2]].waitForExistence(timeout: 10)) == true
                self.helper.showJournal()
                expect(self.journalChildren.element(matching: NSPredicate(format: "value = %@", titles[2])).firstMatch.waitForExistence(timeout: 2)) == true
                expect(self.journalChildren.element(boundBy: 0).value as? String) == titles[0]
                expect(self.journalChildren.element(boundBy: 1).value as? String) == titles[1]
                expect(self.journalChildren.element(boundBy: 2).value as? String) == titles[2]
            }

            it("can navigate links in collected text") {
                self.omnibarHelper.navigateTo(text: urls[0])

                let searchText = "A red panda at the "
                let linkText = "Cincinnati Zoo"
                let fullText = searchText + linkText

                // Get locations of the text
                let parent = self.app.webViews.firstMatch.tables.cells.containing(.staticText,
                                                                                  identifier: searchText).element
                let textElement = parent.staticTexts[searchText]
                let textElementStart = textElement.coordinate(withNormalizedOffset: CGVector(dx: -0.2, dy: 0.5))
                let textElementMiddle = textElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                // click at start of element1 to make sure the page has focus
                textElementStart.click()
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
                expect(self.journalChildren.count) == 2
                expect(self.journalChildren.element(boundBy: 0).value as? String) == titles[0]
                expect((self.journalChildren.element(boundBy: 1).value as? String)?.contains(fullText)) == true
                // tap on collected sublink (end of new bullet)
                let linkCoordinate = self.journalChildren.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
                linkCoordinate.click()
                // tap on a link in the page, should be added to opened bullet
                let lionLink = self.app.webViews.staticTexts["California sea lions"].firstMatch
                expect(lionLink.waitForExistence(timeout: 4)) == true
                lionLink.tap()
                self.helper.showJournal()
                expect(self.journalChildren.count) == 3
                expect(self.journalChildren.element(boundBy: 2).value as? String) == "California sea lion - Wikipedia"
            }
        }
        
        context("PNS") {
            beforeEach {
                self.manualBeforeTestSuite()
                self.helper.tapCommand(.destroyDB)
                self.continueAfterFailure = false
                self.app.launch()
                self.journalScrollView = self.app.scrollViews["journalView"]
                self.journalChildren = self.journalScrollView.children(matching: .textView)
                    .matching(identifier: "TextNode")
            }
            describe("Shoot") {
                it("dismis shootCardPicker by clicking on page") {
                    self.omnibarHelper.navigateTo(text: urls[7])
                    // Great example of complex selection.
                    let searchText = "Internet, Software, & Telecommunication"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // click and drag between start and end of full text
                    let child = parent.staticTexts[searchText]
                    let start = child.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.1))
                    let end = child.coordinate(withNormalizedOffset: CGVector(dx: 1.1, dy: 1))
                    start.click(forDuration: 1, thenDragTo: end)
                    
                    // Press option once to enable shoot mode
                    XCUIElement.perform(withKeyModifiers: .option) {}
                    
                    let shootSelections = self.app.otherElements.matching(identifier:"ShootFrameSelection")
                    expect(shootSelections.count) == 1
                    
                    let emptyLocation = child.coordinate(withNormalizedOffset: CGVector(dx: -0.2, dy: 0.1))
                    start.click()
                    sleep(1)
                    let shootSelections2 = self.app.otherElements.matching(identifier:"ShootFrameSelection")
                    expect(shootSelections2.count) == 0
                }
            }
            describe("Select") {
                it("frame position placement") {
                    self.omnibarHelper.navigateTo(text: urls[7])
                    // Great example of complex selection.
                    let searchText = "Internet, Software, & Telecommunication"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // click and drag between start and end of full text
                    let child = parent.staticTexts[searchText]
                    let start = child.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.1))
                    let end = child.coordinate(withNormalizedOffset: CGVector(dx: 1.1, dy: 1))
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
                    self.helper.tapCommand(.resizeWindowLandscape)
                    
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
                    self.omnibarHelper.navigateTo(text: urls[7])
                    // Great example of complex selection.
                    let searchText = "Internet, Software, & Telecommunication"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    let child = parent.staticTexts[searchText]
                    let start = child.coordinate(withNormalizedOffset: CGVector(dx: -0.2, dy: 0.5))
                    let center = child.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    // click at middle of searchText to focus on page
                    start.click()
                    
                    // Hold option to enable point mode
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        center.hover()
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Zoom in
                        self.app.typeKey("+", modifierFlags: .command)
                        self.app.typeKey("+", modifierFlags: .command)
                        self.app.typeKey("+", modifierFlags: .command)
                        center.hover()
                        
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Zoom out
                        self.app.typeKey("-", modifierFlags: .command)
                        self.app.typeKey("-", modifierFlags: .command)
                        self.app.typeKey("-", modifierFlags: .command)
                        center.hover()
                        
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Scroll page
                        self.app.webViews.firstMatch.scroll(byDeltaX: 0, deltaY: -200)
                        center.hover()

                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Resize window
                        self.helper.tapCommand(.resizeWindowLandscape)
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
                    let noteTitle = "Cool browsers"
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
