//
//  PnSTestView.swift
//  BeamUITests
//
//  Created by Andrii on 17.09.2021.
//

import Foundation
import XCTest

class PnSTestView: BaseView {
    
    @discardableResult
    func waitForCollectPopUpAppear() -> Bool {
        return self.textField(PnSViewLocators.TextFields.shootCardPickerTextField.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func pointAndShootElement(_ element: XCUIElement) -> PnSTestView {
        element.hoverInTheMiddle()
        XCUIApplication.perform(withKeyModifiers: .option) {
            // sometimes UITest does not do the focus on the screen, need to add additional click on PnS area
            element.clickInTheMiddle()
            if !waitForCollectPopUpAppear(){
                otherElement(PnSViewLocators.Other.pointFrame.accessibilityIdentifier).clickOnExistence()
            }
        }
        waitForCollectPopUpAppear()
        return self
    }
    
    func addToNoteByName(_ elementToAdd: XCUIElement, _ noteName: String, _ createNote: Bool = false) {
        pointAndShootElement(elementToAdd)
        let destinationNote = app.windows.textFields.matching(identifier: PnSViewLocators.TextFields.shootCardPickerTextField.accessibilityIdentifier).firstMatch
        _ = destinationNote.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        destinationNote.clickInTheMiddle()
        typeKeyboardKey(.delete)
        destinationNote.typeText(noteName)

        let omniboxView = OmniBoxTestView()
        let notesResults = createNote ? omniboxView.getCreateNoteAutocompleteElementQuery() : omniboxView.getNoteAutocompleteElementQuery()
        XCTAssertTrue(notesResults.firstMatch.waitForExistence(timeout: BaseTest.implicitWaitTimeout), "PnS Note picker drop down didn't appear")
        notesResults.element(boundBy: 0).clickOnExistence()
    }
    
    @discardableResult
    func addToTodayNote(_ elementToAdd: XCUIElement) -> PnSTestView {
        pointAndShootElement(elementToAdd)
        let destinationCard = app.textFields.matching(identifier: PnSViewLocators.TextFields.shootCardPickerTextField.accessibilityIdentifier).firstMatch
        _ = destinationCard.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
        destinationCard.clickOnExistence()
        typeKeyboardKey(.delete)
        typeKeyboardKey(.enter)
        return self
    }
    
    @discardableResult
    func passFailedToCollectPopUpAlert() -> PnSTestView {
        getSendBugReportButtonElement().clickOnExistence()
        return self
    }
    
    func getSendBugReportButtonElement() -> XCUIElement {
        return button("Send Bug Report")
    }
    
    func pressOptionButtonFor(seconds: UInt32) {
        XCUIElement.perform(withKeyModifiers: .option) {
            sleep(seconds)
        }
    }
    
    //Too unstable due to fast pop-up disappearing, could cause false failures
    func openNoteFromSuccessWithoutAddedItemsPopUp(_ noteName: String) -> NoteTestView {
        _ = staticText(PnSViewLocators.StaticTexts.addedToPopup.accessibilityIdentifier + noteName).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
        staticText(PnSViewLocators.StaticTexts.addedToPopup.accessibilityIdentifier + noteName).clickOnExistence()
        return NoteTestView()
    }
    
    func getShootFrameSelection() -> XCUIElementQuery {
        return app.otherElements.matching(identifier:PnSViewLocators.Other.shootFrameSelection.accessibilityIdentifier)
    }
    
    func getShootFrameSelectionLabelElement() -> XCUIElement {
        return app.staticTexts.matching(identifier: PnSViewLocators.Other.shootFrameSelectionLabel.accessibilityIdentifier).element
    }
    
    func assertAddedNumberOfItemsToNoteSuccessfully(_ numberOfItemsAdded: String, _ noteName: String) -> Bool {
        return staticText(numberOfItemsAdded + PnSViewLocators.StaticTexts.addedToPopupPartWithNumber.accessibilityIdentifier + noteName).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
    func assertAddedToNoteSuccessfully(_ noteName: String) -> Bool {
        return staticText(PnSViewLocators.StaticTexts.addedToPopup.accessibilityIdentifier + noteName).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
    func assertPointFrameExists() -> Bool {
        return otherElement(PnSViewLocators.Other.pointFrame.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
    func assertNumberOfAvailablePointFrames(_ expectedNumber: Int ) -> Bool {
        _ = otherElement(PnSViewLocators.Other.pointFrame.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
        return app.otherElements.matching(identifier:PnSViewLocators.Other.pointFrame.accessibilityIdentifier).count == expectedNumber
    }
    
    func assertNumberOfAvailableShootFrameSelection(_ expectedNumber: Int ) -> Bool {
        _ = otherElement(PnSViewLocators.Other.shootFrameSelection.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
        return app.otherElements.matching(identifier:PnSViewLocators.Other.shootFrameSelection.accessibilityIdentifier).count == expectedNumber
    }
    
    func assertBetweenRange(value: CGFloat, start: CGFloat, end: CGFloat, accuracy: CGFloat = 0) {
        let accuracyStart = start - accuracy
        let accuracyEnd = end + accuracy
        let message = "\(value) isn't between \(start) and \(end) within accuracy: \(accuracy)"
        XCTAssertTrue(accuracyStart...accuracyEnd ~= value, message)
    }
    
    func assertFramePositions(searchText: String, identifier: String, message: String? = nil) {
        guard let message = message else {
            let message = "\(identifier) location doesn't match \"\(searchText)\" location"
            assertFramePositions(searchText: searchText, identifier: identifier, message: message)
            return
        }
        let padding: CGFloat = 16
        
        // Delay because of animations
        sleep(1)
        /// Hover element to make it active
        let referenceElementMiddle = self.app.webViews.staticTexts[searchText].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        referenceElementMiddle.hover()

        /// Assert one element exists
        let PnsFrames = self.app.otherElements.matching(identifier: identifier)
        XCTAssertEqual(PnsFrames.count, 1)

        // Expect element to be correctly positioned
        let PnsFrame = self.app.otherElements.matching(identifier: identifier).element.frame
        let referenceElement = self.app.webViews.staticTexts[searchText].firstMatch.frame
        
        /// Assert X location
        XCTAssertEqual(PnsFrame.origin.x, referenceElement.origin.x, accuracy: 10, message)
        
        /// Assert Y location
        let start = referenceElement.origin.y - padding
        let end = referenceElement.origin.y + referenceElement.height + padding
        assertBetweenRange(value: PnsFrame.origin.y, start: start, end: end, accuracy: 10)
        
        /// Assert width size
        XCTAssertEqual(PnsFrame.width, referenceElement.width + padding, accuracy: 10, message)
        
        /// Assert height size
        XCTAssertEqual(PnsFrame.height, referenceElement.height + padding, accuracy: 10, message)
    }
    
    func getCopyButton() -> XCUIElement {
        waitForCollectPopUpAppear()
        return staticText(PnSViewLocators.StaticTexts.copy.accessibilityIdentifier)
    }
    
    func getShareButton() -> XCUIElement {
        waitForCollectPopUpAppear()
        return image(PnSViewLocators.StaticTexts.share.accessibilityIdentifier)
    }
    
}
