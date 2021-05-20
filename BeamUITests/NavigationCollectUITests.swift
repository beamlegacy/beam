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
            self.helper.tapCommand(.resizeWindowPortrait)
            self.continueAfterFailure = false
            self.app.launch()
            self.journalScrollView = self.app.scrollViews["journalView"]
            self.journalChildren = self.journalScrollView.children(matching: .textView)
                .matching(identifier: "TextNode")
            // reset to default zoom level
            self.app.typeKey("0", modifierFlags: .command)
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

        describe("Point and Shoot") {
            let urls = [
                "en.wikipedia.org/wiki/Red_panda",
            ]
            let titles = [
                "Red panda - Wikipedia",
            ]
            
            describe("Select") {
                it("can select text, press Option key and add to note") {
                    self.omnibarHelper.navigateTo(text: urls[0])
                    // Selecting the "A red panda at the [Cincinnati Zoo]" string,
                    // which is composed of two elements, text and then link.
                    // Great example of complex selction.
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
                    
                    // Press option once
                    XCUIElement.perform(withKeyModifiers: .option) {}
                    
                    // Add to today's note
                    self.helper.addNote()
                    
                    // Confirm text is saved in Journal
                    self.helper.showJournal()
                    expect(self.journalChildren.count) == 2
                    expect(self.journalChildren.element(boundBy: 0).value as? String) == titles[0]
                    expect((self.journalChildren.element(boundBy: 1).value as? String)?.contains(fullText)) == true
                }
                
                it("shooting text, then pressing and releasing option, shouldn't keep shoot frames visible") {
                    self.omnibarHelper.navigateTo(text: "en.wikipedia.org/wiki/Point-and-shoot_camera")
                    // Great example of complex selction.
                    let searchText = "Point-and-shoot camera"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // click and drag between start and end of full text
                    let firstChild = parent.staticTexts[searchText]
                    let start = firstChild.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
                    let end = firstChild.coordinate(withNormalizedOffset: CGVector(dx: 1.1, dy: 0.5))
                    start.click(forDuration: 1, thenDragTo: end)
                    
                    // Press option once
                    XCUIElement.perform(withKeyModifiers: .option) {}
                    
                    // Add to today's note
                    self.helper.addNote()
                    
                    // Press option once
                    XCUIElement.perform(withKeyModifiers: .option) {
                        sleep(1)
                    }
                    
                    // Expect to have no ShootFrameSelections visible
                    let shootSelections = self.app.otherElements.matching(identifier:"ShootFrameSelection")
                    expect(shootSelections.count) == 0
                }
                
                it("Resizing in shooting mode should update shootFrame size and location") {
                    self.omnibarHelper.navigateTo(text: "en.wikipedia.org/wiki/Piranhaconda")
                    // Great example of complex selection.
                    let searchText = "Directed by"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // Select
                    let firstChild = parent.staticTexts[searchText]
                    let start = firstChild.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
                    let end = firstChild.coordinate(withNormalizedOffset: CGVector(dx: 1.1, dy: 0.5))
                    start.click(forDuration: 1, thenDragTo: end)
                    
                    // Tap option
                    XCUIElement.perform(withKeyModifiers: .option) {}
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    // Resize window
                    self.helper.tapCommand(.resizeWindowLandscape)
                    // After going to the application menu, we should refocus on the window
                    start.click()
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    
                    // Add to today's note
                    self.helper.addNote()
                    
                    let shootSelections = self.app.otherElements.matching(identifier:"PointFrame")
                    expect(shootSelections.count) == 0
                    
                    // Resize window to inital size
                    self.helper.tapCommand(.resizeWindowPortrait)
                }
                
                it("Resizing in shooting mode with large text selection should update shootFrame size and location") {
                    self.omnibarHelper.navigateTo(text: "text.npr.org/996515792")
                    // Great example of complex selection.
                    let searchText = "By Michaeleen Doucleff"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // Select
                    let firstChild = parent.staticTexts[searchText]
                    let start = firstChild.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
                    let end = firstChild.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
                    start.click(forDuration: 1, thenDragTo: end)
                    
                    // Tap option
                    XCUIElement.perform(withKeyModifiers: .option) {}
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    // Resize window
                    self.helper.tapCommand(.resizeWindowLandscape)
                    // After going to the application menu, we should refocus on the window
                    start.click()
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    
                    // Add to today's note
                    self.helper.addNote()
                    
                    let shootSelections = self.app.otherElements.matching(identifier:"PointFrame")
                    expect(shootSelections.count) == 0
                    
                    // Resize window to inital size
                    self.helper.tapCommand(.resizeWindowPortrait)
                }
            }
            
            describe("Point") {
                it("can hold Option key, clicking and add to note") {
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
                }
                
                it("shooting text, then resizing, should update pointFrame position") {
                    self.omnibarHelper.navigateTo(text: "en.wikipedia.org/wiki/Netscape")
                    // Great example of complex selection.
                    let searchText = "Internet, Software, & Telecommunication"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // Point and Shoot
                    let textElement = parent.staticTexts[searchText]
                    let textElementMiddle = textElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    
                    // click at start of element1 to make sure the page has focus
                    textElementMiddle.click()
                    
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Clicking element to trigger shooting mode
                        textElementMiddle.click()
                        // Release option
                    }
                    // Add to today's note
                    self.helper.addNote()
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Release option
                    }
                    
                    // Resize window
                    self.helper.tapCommand(.resizeWindowLandscape)
                    // After going to the application menu, we should refocus on the window
                    textElementMiddle.click()
                    
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Release option
                    }
                    
                    let shootSelections = self.app.otherElements.matching(identifier:"PointFrame")
                    expect(shootSelections.count) == 0
                    
                    // Resize window to inital size
                    self.helper.tapCommand(.resizeWindowPortrait)
                }

                it("shooting text, then scrolling, should scroll pointFrame positions") {
                    self.omnibarHelper.navigateTo(text: "en.wikipedia.org/wiki/Netscape")
                    // Great example of complex selction.
                    let searchText = "Internet, Software, & Telecommunication"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // Point and Shoot
                    let textElement = parent.staticTexts[searchText]
                    let textElementMiddle = textElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    
                    // click at start of element1 to make sure the page has focus
                    textElementMiddle.click()
                    
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Clicking element to trigger shooting mode
                        textElementMiddle.click()
                        // Release option
                    }
                    
                    // Add to today's note
                    self.helper.addNote()
                    
                    let scrollDeltaY: CGFloat = 200
                    
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Release option
                    }
                    
                    // Scroll window
                    self.app.webViews.firstMatch.scroll(byDeltaX: 0, deltaY: -scrollDeltaY)
                    textElementMiddle.hover()
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Release option
                    }
                    
                    let shootSelections = self.app.otherElements.matching(identifier:"PointFrame")
                    expect(shootSelections.count) == 0
                }
                
                it("scrolling, then shooting text, should correctly position: PointFrame, ShootFrame, ShootCardPicker UI elements") {
                    self.omnibarHelper.navigateTo(text: "en.wikipedia.org/wiki/Piranhaconda")
                    
                    let scrollDeltaY: CGFloat = 200
                    // Scroll down
                    expect(self.app.webViews.firstMatch.waitForExistence(timeout: 4)) == true
                    self.app.webViews.firstMatch.scroll(byDeltaX: 0, deltaY: -scrollDeltaY)
                    
                    // Great example of complex selction.
                    let searchText = "Directed by"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // Point and Shoot
                    let textElement = parent.staticTexts[searchText]
                    let textElementMiddle = textElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    
                    // click at start of element1 to make sure the page has focus
                    textElementMiddle.click()
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Clicking element to trigger shooting mode
                        textElementMiddle.click()
                        // Release option
                    }
                    sleep(1)
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    self.helper.assertShootCardPickerLabelPosition(referenceElement: textElement)
                    // Add to today's note
                    self.helper.addNote()
                }
                
                it("scrolling, then scroll up while shooting text, should correctly position: PointFrame, ShootFrame, ShootCardPicker UI elements") {
                    self.omnibarHelper.navigateTo(text: "en.wikipedia.org/wiki/Piranhaconda")
                    
                    let scrollDeltaY: CGFloat = 200
                    // Scroll down
                    expect(self.app.webViews.firstMatch.waitForExistence(timeout: 4)) == true
                    self.app.webViews.firstMatch.scroll(byDeltaX: 0, deltaY: -scrollDeltaY)
                    
                    // Great example of complex selction.
                    let searchText = "Directed by"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // Point and Shoot
                    let textElement = parent.staticTexts[searchText]
                    let textElementMiddle = textElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    
                    // click at start of element1 to make sure the page has focus
                    textElementMiddle.click()
                    
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Clicking element to trigger shooting mode
                        textElementMiddle.click()
                        // Release option
                    }
                    sleep(1)
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    self.helper.assertShootCardPickerLabelPosition(referenceElement: textElement)
                    
                    // While still shooting...
                    // Scroll up
                    self.app.webViews.firstMatch.scroll(byDeltaX: 0, deltaY: scrollDeltaY)
                    sleep(1)
                    
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    self.helper.assertShootCardPickerLabelPosition(referenceElement: textElement)
                    
                    // Add to today's note
                    self.helper.addNote()
                }
                
                it("Resizing in pointing mode should update pointFrame size and location") {
                    self.omnibarHelper.navigateTo(text: "en.wikipedia.org/wiki/Netscape")
                    // Great example of complex selection.
                    let searchText = "Internet, Software, & Telecommunication"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // Point and Shoot
                    let textElement = parent.staticTexts[searchText]
                    let textElementMiddle = textElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    // click at start of element1 to make sure the page has focus
                    textElementMiddle.click()
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Clicking element to trigger shooting mode
                        textElementMiddle.click()
                        // Release option
                    }
                    
                    // Add to today's note
                    self.helper.addNote()
                    
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Resize window
                        self.helper.tapCommand(.resizeWindowLandscape)
                        textElementMiddle.hover()
                        // Assert pointFrame again
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Release option
                    }
                    
                    let shootSelections = self.app.otherElements.matching(identifier:"PointFrame")
                    expect(shootSelections.count) == 0
                    
                    // Resize window to inital size
                    self.helper.tapCommand(.resizeWindowPortrait)
                }
                
                it("Resizing in shooting mode should update shootFrame size and location") {
                    self.omnibarHelper.navigateTo(text: "en.wikipedia.org/wiki/Piranhaconda")
                    // Great example of complex selection.
                    let searchText = "Directed by"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // Point and Shoot
                    let textElement = parent.staticTexts[searchText]
                    let textElementMiddle = textElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    
                    // click at start of element1 to make sure the page has focus
                    textElementMiddle.click()
                    
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Clicking element to trigger shooting mode
                        textElementMiddle.click()
                        self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                        // Resize window
                        self.helper.tapCommand(.resizeWindowLandscape)
                        // After going to the application menu, we should refocus on the window
                        textElementMiddle.click()
                        self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                        // Release option
                    }
                    // Add to today's note
                    self.helper.addNote()
                    
                    let shootSelections = self.app.otherElements.matching(identifier:"PointFrame")
                    expect(shootSelections.count) == 0
                    
                    // Resize window to inital size
                    self.helper.tapCommand(.resizeWindowPortrait)
                }
                
                it("Resizing and Scrolling in shooting mode should update shootFrame size and location") {
                    // Resize window so we have a known starting size
                    self.helper.tapCommand(.resizeWindowPortrait)
                    
                    self.omnibarHelper.navigateTo(text: "en.wikipedia.org/wiki/Piranhaconda")
                    // Great example of complex selection.
                    let searchText = "Directed by"
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    
                    // Point and Shoot
                    let textElement = parent.staticTexts[searchText]
                    let textElementMiddle = textElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    
                    // set scroll distance
                    let scrollDeltaY: CGFloat = 200
                    
                    // click at start of element1 to make sure the page has focus
                    textElementMiddle.click()
                    
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Clicking element to trigger shooting mode
                        textElementMiddle.click()
                        self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                        // Resize window
                        self.helper.tapCommand(.resizeWindowLandscape)
                        // Refocus on webview
                        textElementMiddle.click()
                        // Scroll window
                        self.app.webViews.firstMatch.scroll(byDeltaX: 0, deltaY: -scrollDeltaY)
                        // Assert ShootFrame again
                        self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                        // Release option
                    }
                    
                    // Add to today's note
                    self.helper.addNote()
                    
                    let shootSelections = self.app.otherElements.matching(identifier:"PointFrame")
                    expect(shootSelections.count) == 0
                    
                    // Resize window to inital size
                    self.helper.tapCommand(.resizeWindowPortrait)
                }
                
                it("After shooting text, that pointFrame should show card association label") {
                    self.omnibarHelper.navigateTo(text: "en.wikipedia.org/wiki/Netscape")
                    
                    let searchText = "Internet, Software, & Telecommunication"
                    let noteTitle = "Cool browsers"
                    
                    // Get locations of the text
                    let parent = self.app.webViews.firstMatch.tables.cells.containing(.staticText,
                                                                                      identifier: searchText).element
                    let textElement = parent.staticTexts[searchText]
                    
                    // tap element
                    textElement.tapInTheMiddle()
                    
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Clicking element to trigger shooting mode
                        textElement.tapInTheMiddle()
                        // Release option
                    }
                    
                    // Add to today's note
                    self.helper.addNote(noteTitle: noteTitle)
                    
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option, hover text
                        textElement.hover()
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Show card association label
                        let ShootFrameSelectionLabel = self.app.staticTexts.matching(identifier: "ShootFrameSelectionLabel").element
                        let shootValue = ShootFrameSelectionLabel.value as! String
                        expect(shootValue) == noteTitle
                    }
                }
                
                it("After shooting text and resizing pointFrame should show card association label") {
                    // Resize window so we have a known starting size
                    self.helper.tapCommand(.resizeWindowPortrait)
                    self.omnibarHelper.navigateTo(text: "en.wikipedia.org/wiki/Netscape")
                    
                    let searchText = "Internet, Software, & Telecommunication"
                    let noteTitle = "Cool browsers"
                    
                    // Get locations of the text
                    let parent = self.app.webViews.firstMatch.tables.cells.containing(.staticText,
                                                                                      identifier: searchText).element
                    let textElement = parent.staticTexts[searchText]
                    
                    // tap element
                    textElement.tapInTheMiddle()
                    
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Clicking element to trigger shooting mode
                        textElement.tapInTheMiddle()
                        // Release option
                    }
                    // Add to today's note
                    self.helper.addNote(noteTitle: noteTitle)
                    // Assert card association
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option, hover text
                        textElement.hover()
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        
                        let ShootFrameSelectionLabel = self.app.staticTexts.matching(identifier: "ShootFrameSelectionLabel").element
                        let shootValue = ShootFrameSelectionLabel.value as! String
                        expect(shootValue) == noteTitle
                    }
                    // Resize window
                    self.helper.tapCommand(.resizeWindowLandscape)
                    // Refocus webview
                    textElement.click()
                    // Assert cards association
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option, hover text
                        textElement.hover()
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        
                        let ShootFrameSelectionLabels = self.app.staticTexts.matching(identifier: "ShootFrameSelectionLabel")
                        expect(ShootFrameSelectionLabels.count) == 1
                        let shootValue = ShootFrameSelectionLabels.element.value as! String
                        expect(shootValue) == noteTitle
                    }
                    
                    // Reset window size
                    self.helper.tapCommand(.resizeWindowPortrait)
                }
                
                it("Zoom (CMD +) should position ShootFrames correctly") {
                    self.omnibarHelper.navigateTo(text: "en.wikipedia.org/wiki/Point-and-shoot_camera")
                    // Great example of complex selction.
                    let searchText = "Point-and-shoot camera"
                    // Get locations of the text
                    let parent = self.app.webViews.containing(.staticText,
                                                              identifier: searchText).element
                    let textElement = parent.staticTexts[searchText]
                    let textElementStart = textElement.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
                    let textElementMiddle = textElement.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    
                    // click at start of element1 to make sure the page has focus
                    textElementStart.click()
                    // Hold option
                    XCUIElement.perform(withKeyModifiers: .option) {
                        // While holding option
                        self.helper.assertFramePositions(searchText: searchText, identifier: "PointFrame")
                        // Clicking element to trigger shooting mode
                        textElementMiddle.click()
                        // Release option
                    }
                    
                    // confirm positions
                    // Expect to have 1 ShootFrameSelection visible
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    // Zoom in on page
                    self.app.typeKey("+", modifierFlags: .command)
                    self.app.typeKey("+", modifierFlags: .command)
                    self.app.typeKey("+", modifierFlags: .command)
                    // confirm positions
                    self.helper.assertFramePositions(searchText: searchText, identifier: "ShootFrameSelection")
                    // Add to today's note
                    self.helper.addNote()
                }
            }
        }
    }
}
