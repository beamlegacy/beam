//
//  CaptureCopyShareTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 18.04.2022.
//

import Foundation
import XCTest

class CaptureCopyShareTests: BaseTest {
    
    let pnsView = PnSTestView()
    var journalView: JournalTestView!
    let textToCapture = " capital letter \"I\". The purpose of this cursor is to indicate that the text beneath the cursor can be highlighted, and sometime"
    
    private func switchToJournalAndPasteToFirstNode() {
        shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        journalView.waitForJournalViewToLoad()
        journalView.getNoteByIndex(1).tapInTheMiddle()
        shortcutHelper.shortcutActionInvoke(action: .paste)
    }
    
    private func triggerShareOption(elementToAdd: XCUIElement, title: String, clickMenuItem: Bool = true) {
        pnsView.pointAndShootElement(elementToAdd)
            .getShareButton()
            .clickOnExistence()
        if clickMenuItem {
            pnsView.menuItem(title).clickOnExistence()
        }
    }
    
    override func setUp() {
        step ("GIVEN I launch the app") {
            journalView = launchApp()
        }
    }
    
    func testCopyCapturedText() {
        testrailId("C998")
        step("GIVEN I load the test page") {
            uiMenu.loadUITestPage3()
        }
        
        step ("When I capture text and click Copy") {
            let textElementToAdd = pnsView.staticText(textToCapture)
            pnsView.pointAndShootElement(textElementToAdd)
        }
        
        step ("Then I see copied label") {
            pnsView.getCopyButton().tapInTheMiddle()
            XCTAssertTrue(pnsView.staticText(PnSViewLocators.StaticTexts.copied.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step ("Then I see text is pasted correctly") {
            self.switchToJournalAndPasteToFirstNode()
            let actualText = journalView.getNoteByIndex(1).getStringValue()
            XCTAssertTrue(actualText.contains(textToCapture), "Actual text pasted is \(actualText)") //on some CI machines a backspace is added by some reason*/
        }
    }
    
    func testCopyCapturedImage() {
        testrailId("C998")
        
        step("GIVEN I load the test page") {
            uiMenu.resizeSquare1000()
            uiMenu.loadUITestPage4()
        }
        
        step ("When I capture text and click Copy") {
            let imageItemToAdd = pnsView.image("forest")
            pnsView.pointAndShootElement(imageItemToAdd)
                .getCopyButton()
                .tapInTheMiddle()
        }
           
        step ("Then I see copied label") {
            XCTAssertTrue(pnsView.staticText(PnSViewLocators.StaticTexts.copied.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step ("Then I see image is pasted correctly") {
            self.switchToJournalAndPasteToFirstNode()
            XCTAssertEqual(journalView.getImageNodesCount(), 1)
        }
    }
    
    func testShareCapturedText() {
        testrailId("C999, C1000, C1001, C1002, C1003, C1004")
        let windows = ["Twitter", "Facebook", "LinkedIn", "Reddit"]
        let apps = ["Email", "Messages"]
        
        let textElementToAdd = pnsView.staticText(textToCapture)
        
        step("GIVEN I load the test page") {
            uiMenu.loadUITestPage3()
        }
        
        for windowTitle in windows {
            if windowTitle != windows[2] { //To be removed as part of BE-5195
            step ("Then \(windowTitle) window is opened using Share option") {
                self.triggerShareOption(elementToAdd: textElementToAdd, title: windowTitle)
                _ = webView.waitForWebViewToLoad()
                XCTAssertTrue(waitForIntValueEqual(timeout: BaseTest.implicitWaitTimeout, expectedNumber: 2, query: getNumberOfWindows()), "Second window wasn't opened during \(BaseTest.implicitWaitTimeout) seconds timeout")
                XCTAssertTrue(
                pnsView.isWindowOpenedWithContaining(title: windowTitle) ||
                pnsView.isWindowOpenedWithContaining(title: windowTitle, isLowercased: true)
                    )
                shortcutHelper.shortcutActionInvoke(action: .close)
                }
            } 
        }
        
        step ("Then \(apps.joined(separator: ",")) options exist in Share options") {
            self.triggerShareOption(elementToAdd: textElementToAdd, title: apps[0], clickMenuItem: false)
            XCTAssertTrue(pnsView.menuItem(windows[2]).waitForExistence(timeout: BaseTest.minimumWaitTimeout)) //To be removed as part of BE-5195
            for appTitle in apps {
                XCTAssertTrue(pnsView.menuItem(appTitle).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            }
        }
    }
    
}
