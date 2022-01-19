//
//  BaseView.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation
import XCTest

//Designed to be inherited by Views classes following Page Object pattern
class BaseView {
    
    var app: XCUIApplication { XCUIApplication() }
    let implicitWaitTimeout = TimeInterval(10)
    let minimumWaitTimeout = TimeInterval(2)
    let defaultPressDurationSeconds = 1.5
    let errorFetchStringValue = "ERROR:failed to fetch string value from "
    let shortcutsHelper = ShortcutsHelper()
    //Wrapper over the elements
    func label(_ element: String) -> XCUIElement {
        return app.windows.staticTexts[element]
    }
    
    func textField(_ element: String) -> XCUIElement {
        return app.windows.textFields[element]
    }
    
    func textView(_ element: String) -> XCUIElement {
        return app.windows.textViews[element]
    }
    
    func staticText(_ element: String) -> XCUIElement {
        return app.windows.staticTexts[element]
    }
    
    func searchField(_ element: String) -> XCUIElement {
        return app.windows.searchFields[element]
    }
    
    func splitter(_ element: String) -> XCUIElement {
        return app.windows.splitters[element]
    }
    
    func secureTextField(_ element: String) -> XCUIElement {
        return app.windows.secureTextFields[element]
    }
    
    func checkBox(_ element: String) -> XCUIElement {
        return app.windows.checkBoxes[element]
    }
    
    func button(_ element: String) -> XCUIElement {
        return app.windows.buttons[element]
    }
    
    func group(_ element: String) -> XCUIElement {
        return app.windows.groups[element]
    }
    
    func image(_ element: String) -> XCUIElement {
        return app.windows.images[element]
    }
    
    func table(_ element: String) -> XCUIElement {
        return app.windows.tables[element]
    }
    
    func collection(_ element: String) -> XCUIElement {
        return app.windows.collectionViews[element]
    }
    
    func otherElement(_ element: String) -> XCUIElement {
        return app.windows.otherElements[element]
    }
    
    func scrollView(_ element: String) -> XCUIElement {
        return app.windows.scrollViews[element]
    }
    
    func tableTextField(_ element: String) -> XCUIElement {
        return app.windows.tables.textFields[element]
    }
    
    func tableImage(_ element: String) -> XCUIElement {
        return app.windows.tables.images[element]
    }
    
    func menuItem(_ element: String) -> XCUIElement {
        return app.windows.menuItems[element]
    }
    
    func typeKeyboardKey(_ key: XCUIKeyboardKey, _ numberOfTimes: Int = 1) {
        for _ in 1...numberOfTimes {
            self.app.typeKey(key, modifierFlags: [])
        }
    }
    
    //Omni bar search field is accessible from any view
    @discardableResult
    func clickOmniBoxSearchField() -> OmniBoxTestView {
        let omniboxView = OmniBoxTestView()
        omniboxView.getOmniBoxSearchField().click()
        return omniboxView
    }
    
    @discardableResult
    func searchInOmniBox(_ searchText: String, _ typeReturnButton: Bool) -> WebTestView {
        populateOmniboxWith(searchText)
        if typeReturnButton {
            typeKeyboardKey(.enter)
            _ = button(ToolbarLocators.Buttons.openCardButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        }
        return WebTestView()
    }
    
    func getElementStringValue(element: XCUIElement) -> String {        
        return element.value as? String ?? errorFetchStringValue + element.identifier
    }
        
    @discardableResult
    func populateOmniboxWith(_ text: String) -> OmniBoxTestView {
        let omniSearchField = searchField(ToolbarLocators.SearchFields.omniSearchField.accessibilityIdentifier)
        if !omniSearchField.exists {
            shortcutsHelper.shortcutActionInvoke(action: .openLocation)
        }
        omniSearchField.tapInTheMiddle()
        omniSearchField.clear()
        omniSearchField.typeText(text)
        WaitHelper().waitForStringValueEqual(text, OmniBoxTestView().getOmniBoxSearchField(), minimumWaitTimeout)
        return OmniBoxTestView()
    }
    
    @discardableResult
    func openWebsite(_ url: String) -> WebTestView {
        _ = populateOmniboxWith(url)
        self.typeKeyboardKey(.enter)
        return WebTestView()
    }
    
    @discardableResult
    func pasteText(textToPaste: String) -> BaseView {
        let text = textToPaste
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        shortcutsHelper.shortcutActionInvoke(action: .paste)
        return self
    }
    
    @discardableResult
    func triggerSearchField() -> SearchTestView {
        shortcutsHelper.shortcutActionInvoke(action: .search)
        return SearchTestView()
    }
    
    @discardableResult
    func selectAllAndDelete() -> BaseView {
        ShortcutsHelper().shortcutActionInvoke(action: .selectAll)
        typeKeyboardKey(.delete)
        return self
    }
    
    func isSafariAutoCompleteOpen() -> Bool {
        return textField("SafariPlatformSupportAutoCompleteWindow").exists
    }
    
    @discardableResult
    func zoomIn(numberOfTimes: Int) -> BaseView {
        for _ in 1...numberOfTimes {
            app.typeKey("+", modifierFlags: .command)
        }
        return self
    }
    
    @discardableResult
    func zoomOut(numberOfTimes: Int) -> BaseView {
        for _ in 1...numberOfTimes {
            app.typeKey("-", modifierFlags: .command)
        }
        return self
    }
    
    @discardableResult
    func clickStartOfTextAndDragTillEnd(textIdentifier: String, elementToPerformAction: XCUIElement) -> BaseView {
        //let child = elementToPerformAction.staticTexts[textIdentifier]
        let start = elementToPerformAction.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.1))
        let end = elementToPerformAction.coordinate(withNormalizedOffset: CGVector(dx: 1.1, dy: 0.9))
        start.click(forDuration: 1, thenDragTo: end)
        return self
    }
    
    func getCenterOfElement(element: XCUIElement) -> XCUICoordinate {
        return element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }
    
    @discardableResult
    func openCardFromRecentsList(cardTitleToOpen: String) -> CardTestView {
        let cardView = CardTestView()
        let cardSwitcherButton = cardView.app.buttons.element(matching: NSPredicate(format: "identifier = '\(ToolbarLocators.Buttons.cardSwitcher.accessibilityIdentifier)' AND value = '\(cardTitleToOpen)'")).firstMatch
        cardSwitcherButton.clickOnExistence()
        XCTAssertTrue(cardView.waitForCardToOpen(cardTitle: cardTitleToOpen), "\(cardTitleToOpen) note is failed to load")
        return cardView
    }
}
