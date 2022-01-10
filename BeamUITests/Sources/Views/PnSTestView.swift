//
//  PnSTestView.swift
//  BeamUITests
//
//  Created by Andrii on 17.09.2021.
//

import Foundation
import XCTest

class PnSTestView: BaseView {
    
    func triggerAddToCardPopup(_ element: XCUIElement) {
        XCUIElement.perform(withKeyModifiers: .option) {
            let elementMiddle = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            // click at middle of element1 to make sure the page has focus
            elementMiddle.hover()
            _ = otherElement(PnSViewLocators.Other.pointFrame.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
            elementMiddle.click()
        }
    }
    
    @discardableResult
    func waitForCollectPopUpAppear() -> Bool {
        return self.textField(PnSViewLocators.Other.shootCardPicker.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func pointAndShootElement(_ element: XCUIElement) {
        XCUIElement.perform(withKeyModifiers: .option) {
            element.click()
        }
    }
    
    func addToCardByName(_ elementToAdd: XCUIElement, _ cardName: String, _ noteText: String = "", _ isNewCard: Bool = false) {
        triggerAddToCardPopup(elementToAdd)
        
        if noteText != "" {
            textField(PnSViewLocators.TextFields.addNote.accessibilityIdentifier).clickAndType(noteText)
        }
        
        let destinationCard = app.windows.textFields.matching(identifier: PnSViewLocators.Other.shootCardPicker.accessibilityIdentifier).firstMatch
        destinationCard.clickOnExistence()
        typeKeyboardKey(.delete)
        destinationCard.typeText(cardName)
        
        //WIP, TBD in next PnS tests
        /*if isNewCard {
        }*/
        let cardsDropDown = otherElement(PnSViewLocators.Other.shootCardPicker.accessibilityIdentifier)
        XCTAssertTrue(cardsDropDown.waitForExistence(timeout: implicitWaitTimeout), "PnS Note picker drop down didn't appear")
        app.windows.children(matching: .other).matching(identifier: PnSViewLocators.Other.shootCardPicker.accessibilityIdentifier).element(boundBy: 0).clickOnExistence()
        destinationCard.tapInTheMiddle()
        XCTAssertTrue(WaitHelper().waitForDoesntExist(cardsDropDown), "PnS Note picker drop down remains opened")
        typeKeyboardKey(.enter)
    }
    
    func addToTodayCard(_ elementToAdd: XCUIElement) {
        XCUIElement.perform(withKeyModifiers: .option) {
            let elementMiddle = elementToAdd.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            // click at middle of element1 to make sure the page has focus
            elementMiddle.hover()
            _ = otherElement(PnSViewLocators.Other.pointFrame.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
            elementMiddle.click()
            let destinationCard = app.textFields.matching(identifier: PnSViewLocators.Other.shootCardPicker.accessibilityIdentifier).firstMatch
            destinationCard.clickOnExistence()
            typeKeyboardKey(.delete)
            destinationCard.typeText("\r")
        }
    }
    
    @discardableResult
    func passFailedToCollectPopUpAlert() -> PnSTestView {
        button("Send bug report").tap()
        return self
    }
    
    func pressOptionButtonFor(seconds: UInt32) {
        XCUIElement.perform(withKeyModifiers: .option) {
            sleep(seconds)
        }
    }
    
    //Too unstable due to fast pop-up disappearing, could cause false failures
    func openCardFromSuccessWithoutAddedItemsPopUp(_ cardName: String) -> CardTestView {
        _ = staticText(PnSViewLocators.StaticTexts.addedToPopup.accessibilityIdentifier + cardName).waitForExistence(timeout: implicitWaitTimeout)
        staticText(PnSViewLocators.StaticTexts.addedToPopup.accessibilityIdentifier + cardName).click()
        return CardTestView()
    }
    
    func getShootFrameSelection() -> XCUIElementQuery {
        return app.otherElements.matching(identifier:PnSViewLocators.Other.shootFrameSelection.accessibilityIdentifier)
    }
    
    func getShootFrameSelectionLabelElement() -> XCUIElement {
        return app.staticTexts.matching(identifier: PnSViewLocators.Other.shootFrameSelectionLabel.accessibilityIdentifier).element
    }
    
    func assertAddedNumberOfItemsToCardSuccessfully(_ numberOfItemsAdded: String, _ cardName: String) -> Bool {
        return staticText(numberOfItemsAdded + PnSViewLocators.StaticTexts.addedToPopupPartWithNumber.accessibilityIdentifier + cardName).waitForExistence(timeout: implicitWaitTimeout)
    }
    
    func assertAddedToCardSuccessfully(_ cardName: String) -> Bool {
        return staticText(PnSViewLocators.StaticTexts.addedToPopup.accessibilityIdentifier + cardName).waitForExistence(timeout: implicitWaitTimeout)
    }
    
    func assertPointFrameExists() -> Bool {
        return otherElement(PnSViewLocators.Other.pointFrame.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
    }
    
    func assertNumberOfAvailablePointFrames(_ expectedNumber: Int ) -> Bool {
        _ = otherElement(PnSViewLocators.Other.pointFrame.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        return app.otherElements.matching(identifier:PnSViewLocators.Other.pointFrame.accessibilityIdentifier).count == expectedNumber
    }
    
    func assertNumberOfAvailableShootFrameSelection(_ expectedNumber: Int ) -> Bool {
        _ = otherElement(PnSViewLocators.Other.shootFrameSelection.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
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
}
