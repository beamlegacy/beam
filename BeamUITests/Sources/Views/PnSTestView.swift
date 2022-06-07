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
    func triggerAddToNotePopup(_ element: XCUIElement) -> PnSTestView {
        XCUIElement.perform(withKeyModifiers: .option) {
            let elementMiddle = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            // click at middle of element1 to make sure the page has focus
            elementMiddle.hover()
            _ = otherElement(PnSViewLocators.Other.pointFrame.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
            elementMiddle.click()
        }
        return PnSTestView()
    }
    
    @discardableResult
    func waitForCollectPopUpAppear() -> Bool {
        return self.textField(PnSViewLocators.Other.shootCardPicker.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func pointAndShootElement(_ element: XCUIElement) {
        XCUIElement.perform(withKeyModifiers: .option) {
            element.click()
        }
    }
    
    func addToNoteByName(_ elementToAdd: XCUIElement, _ cardName: String, _ isNewCard: Bool = false) {
        triggerAddToNotePopup(elementToAdd)
        
        let destinationCard = app.windows.textFields.matching(identifier: PnSViewLocators.Other.shootCardPicker.accessibilityIdentifier).firstMatch
        destinationCard.clickOnExistence()
        typeKeyboardKey(.delete)
        destinationCard.typeText(cardName)
        
        //WIP, TBD in next PnS tests
        /*if isNewCard {
        }*/
        let cardsDropDown = otherElement(PnSViewLocators.Other.shootCardPicker.accessibilityIdentifier)
        XCTAssertTrue(cardsDropDown.waitForExistence(timeout: BaseTest.implicitWaitTimeout), "PnS Note picker drop down didn't appear")
        app.windows.children(matching: .other).matching(identifier: PnSViewLocators.Other.shootCardPicker.accessibilityIdentifier).element(boundBy: 0).clickOnExistence()
    }
    
    @discardableResult
    func addToTodayNote(_ elementToAdd: XCUIElement) -> PnSTestView {
        XCUIElement.perform(withKeyModifiers: .option) {
            let elementMiddle = elementToAdd.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            // click at middle of element1 to make sure the page has focus
            elementMiddle.hover()
            _ = otherElement(PnSViewLocators.Other.pointFrame.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
            elementMiddle.click()
            let destinationCard = app.textFields.matching(identifier: PnSViewLocators.Other.shootCardPicker.accessibilityIdentifier).firstMatch
            destinationCard.clickOnExistence()
            typeKeyboardKey(.delete)
            destinationCard.typeText("\r")
        }
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
        staticText(PnSViewLocators.StaticTexts.addedToPopup.accessibilityIdentifier + noteName).click()
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
        return staticText(PnSViewLocators.StaticTexts.copy.accessibilityIdentifier)
    }
    
    func getShareButton() -> XCUIElement {
        return app.windows.children(matching: .image).matching(identifier: PnSViewLocators.StaticTexts.share.accessibilityIdentifier).element(boundBy: 0)
    }
    
    func isWindowOpenedWithContaining(title: String, isLowercased: Bool = false) -> Bool {
        return app.windows.matching(NSPredicate(format: "title CONTAINS '\(isLowercased ? title.lowercased() : title)'")).element.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
}
