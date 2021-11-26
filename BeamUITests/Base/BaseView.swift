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
    func clickOmniBarSearchField() -> OmniBarTestView {
        let omnibarView = OmniBarTestView()
        omnibarView.getOmniBarSearchField().click()
        return omnibarView
    }
    
    @discardableResult
    func searchInOmniBar(_ searchText: String, _ typeReturnButton: Bool) -> WebTestView {
        populateOmnibarWith(searchText)
        if typeReturnButton {
            typeKeyboardKey(.enter)
            _ = button(OmniBarLocators.Buttons.openCardButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        }
        return WebTestView()
    }
    
    func getElementStringValue(element: XCUIElement) -> String {        
        return element.value as? String ?? errorFetchStringValue + element.identifier
    }
        
    @discardableResult
    func populateOmnibarWith(_ text: String) -> OmniBarTestView {
        let omniSearchField = searchField(OmniBarLocators.SearchFields.omniSearchField.accessibilityIdentifier)
        omniSearchField.tapInTheMiddle()
        omniSearchField.clear()
        omniSearchField.typeText(text)
        WaitHelper().waitForStringValueEqual(text, OmniBarTestView().getOmniBarSearchField(), minimumWaitTimeout)
        return OmniBarTestView()
    }
    
    @discardableResult
    func openWebsite(_ url: String) -> WebTestView {
        _ = populateOmnibarWith(url)
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
}
