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
    let journalView = JournalTestView()
    
    private func switchToJournalAndPasteToFirstNode() {
        ShortcutsHelper().shortcutActionInvoke(action: .switchBetweenCardWeb)
        journalView.waitForJournalViewToLoad()
        journalView.getNoteByIndex(1).tapInTheMiddle()
        ShortcutsHelper().shortcutActionInvoke(action: .paste)
    }
    
    func testCopyCapturedText() {
        launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        helper.openTestPage(page: .page3)
        let textToCapture = " capital letter \"I\". The purpose of this cursor is to indicate that the text beneath the cursor can be highlighted, and sometime"
        
        step ("When I capture text and click Copy") {
            let textElementToAdd = pnsView.staticText(textToCapture)
            pnsView.triggerAddToCardPopup(textElementToAdd)
        }
        
        step ("Then I see copied label") {
            pnsView.getCopyButton().tapInTheMiddle()
            XCTAssertTrue(pnsView.staticText(PnSViewLocators.StaticTexts.copied.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step ("Then I see text is pasted correctly") {
            self.switchToJournalAndPasteToFirstNode()
            let actualText = journalView.getElementStringValue(element: journalView.getNoteByIndex(1))
            XCTAssertTrue(actualText.contains(textToCapture), "Actual text pasted is \(actualText)") //on some CI machines a backspace is added by some reason*/
        }
    }
    
    func testCopyCapturedImage() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        helper.tapCommand(.resizeSquare1000)
        
        step ("When I capture text and click Copy") {
            helper.openTestPage(page: .page4)
            let imageItemToAdd = pnsView.image("forest")
            pnsView.triggerAddToCardPopup(imageItemToAdd)
            pnsView.getCopyButton().tapInTheMiddle()
        }
           
        step ("Then I see copied label") {
            XCTAssertTrue(pnsView.staticText(PnSViewLocators.StaticTexts.copied.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step ("Then I see image is pasted correctly") {
            self.switchToJournalAndPasteToFirstNode()
            XCTAssertEqual(journalView.getImageNodesCount(), 1)
        }
    }
    
}
