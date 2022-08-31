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
    /// 5 seconds
    let implicitWaitTimeout = TimeInterval(5)
    /// 2 seconds
    let minimumWaitTimeout = TimeInterval(2)
    let maximumWaitTimeout = TimeInterval(10)
    let defaultPressDurationSeconds = 1.5
    let shortcutHelper = ShortcutsHelper()
    let uiMenu = UITestsMenuBar()

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

    func link(_ element: String) -> XCUIElement {
        return app.windows.links[element]
    }

    func handle(_ element: String) -> XCUIElement {
        return app.windows.handles[element]
    }
    
    func group(_ element: String) -> XCUIElement {
        return app.windows.groups[element]
    }
    
    func webView(_ element: String) -> XCUIElement {
        return app.windows.webViews[element]
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
    
    func popUpButton(_ element: String) -> XCUIElement {
        return app.windows.popUpButtons[element]
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
        omniboxView.getOmniBoxSearchField().clickOnExistence()
        return omniboxView
    }
    
    @discardableResult
    func searchInOmniBox(_ searchText: String, _ typeReturnButton: Bool) -> WebTestView {
        populateOmniboxWith(searchText)
        if typeReturnButton {
            typeKeyboardKey(.enter)
            _ = button(ToolbarLocators.Buttons.openNoteButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            _ = WebTestView().waitForWebViewToLoad()
        }
        return WebTestView()
    }
        
    @discardableResult
    func populateOmniboxWith(_ text: String) -> OmniBoxTestView {
        let omniSearchField = searchField(ToolbarLocators.SearchFields.omniSearchField.accessibilityIdentifier)
        _ = omniSearchField.waitForExistence(timeout: BaseTest.maximumWaitTimeout)
        omniSearchField.clickClearAndType(text)
        BaseTest.waitForStringValueEqual(text, OmniBoxTestView().getOmniBoxSearchField(), BaseTest.minimumWaitTimeout)
        return OmniBoxTestView()
    }
    
    @discardableResult
    func openWebsite(_ url: String) -> WebTestView {
        shortcutHelper.shortcutActionInvoke(action: .openLocation)
        _ = populateOmniboxWith(url)
        self.typeKeyboardKey(.enter)
        return WebTestView()
    }
    
    @discardableResult
    func pasteText(textToPaste: String) -> BaseView {
        let text = textToPaste
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        shortcutHelper.shortcutActionInvoke(action: .paste)
        return self
    }
    
    @discardableResult
    func triggerSearchField() -> SearchTestView {
        shortcutHelper.shortcutActionInvoke(action: .search)
        return SearchTestView()
    }
    
    @discardableResult
    func selectAllAndDelete() -> BaseView {
        shortcutHelper.shortcutActionInvoke(action: .selectAll)
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
    func openNoteFromAllNotesList(noteTitleToOpen: String) -> NoteTestView {
        shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
        AllNotesTestView().openNoteByName(noteTitle: noteTitleToOpen)

        let noteView = NoteTestView()
// Keep this code in case we restore the recent notes topbar
//        let noteSwitcherButton = noteView.app.buttons.element(matching: NSPredicate(format: "identifier = '\(ToolbarLocators.Buttons.noteSwitcher.accessibilityIdentifier)' AND value = '\(noteTitleToOpen)'")).firstMatch
//        noteSwitcherButton.clickOnExistence()
        XCTAssertTrue(noteView.waitForNoteToOpen(noteTitle: noteTitleToOpen), "\(noteTitleToOpen) note is failed to load")
        return noteView
    }
    
    func isWindowOpenedWithContaining(title: String, isLowercased: Bool = false) -> Bool {
        return app.windows.matching(NSPredicate(format: "title CONTAINS '\(isLowercased ? title.lowercased() : title)'")).element.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
    @discardableResult
    func clickHomeIcon() -> JournalTestView {
        button(ToolbarLocators.Buttons.homeButton.accessibilityIdentifier).hoverAndTapInTheMiddle()
        return JournalTestView()
    }
    
    @discardableResult
    func clickOmniboxIcon() -> OmniBoxTestView {
        button(WebViewLocators.Buttons.openOmnibox.accessibilityIdentifier).hoverAndTapInTheMiddle()
        return OmniBoxTestView()
    }
}
