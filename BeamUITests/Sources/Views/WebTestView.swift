//
//  TabsView.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class WebTestView: BaseView {

    var statusText: XCUIElement {
        staticText("webview-status-text")
    }
    
    func getDestinationNoteElement() -> XCUIElement {
        let element = staticText(WebViewLocators.Buttons.destinationCard.accessibilityIdentifier)
        _ = element.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return element
    }
    
    func getDestinationNoteTitle() -> String {
        return getElementStringValue(element: getDestinationNoteElement())
    }
    
    func getBrowserTabTitleValueByIndex(index: Int) -> String {
        return getElementStringValue(element: getBrowserTabTitleElements()[index])
    }
    
    func getBrowserTabTitleElements() -> [XCUIElement] {
        return app.windows.staticTexts.matching(identifier: WebViewLocators.Tabs.tabTitle.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    @discardableResult
    func openAllNotesMenu() -> AllNotesTestView {
        button(ToolbarLocators.Buttons.noteSwitcherAllCards.accessibilityIdentifier).click()
        return AllNotesTestView()
    }
    
    func searchForNoteByTitle(_ title: String) {
        XCTContext.runActivity(named: "Search for '\(title)' note in notes search drop-down") {_ in
        self.getDestinationNoteElement().clickOnHittable()
        searchField(WebViewLocators.SearchFields.destinationCardSearchField.accessibilityIdentifier).typeText(title)
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'autocompleteResult-selected-'")
        app.otherElements.matching(predicate).firstMatch.click()
        }
    }
    
    func openDestinationNoteSearch() -> XCUIElement {
        let element = self.getDestinationNoteElement()
        element.clickOnHittable()
        return element
    }
    
    @discardableResult
    func selectCreateNote(_ searchText: String) -> NoteTestView {
        XCTContext.runActivity(named: "Click on proposed New note option for '\(searchText)' search keyword") {_ in
        // The mouse could overlap the autocomplete result so we should also match on "selected" results
        let predicate = NSCompoundPredicate(
            type: .or,
            subpredicates: [
                NSPredicate(format: "identifier BEGINSWITH 'autocompleteResult-" + searchText + "-createNote'"),
                NSPredicate(format: "identifier BEGINSWITH 'autocompleteResult-selected-" + searchText + "-createNote'")
            ]
        )
        let noteCreationElement = app.otherElements.matching(predicate).firstMatch
        //Try out to replace additional waiting
        //XCTAssertTrue(cardCreationElement.waitForExistence(timeout: BaseTest.minimumWaitTimeout), "\(searchText) is NOT in the create card autocomplete result")
        noteCreationElement.clickOnExistence()
        return NoteTestView()
        }
    }
    
    @discardableResult
    func openDestinationNote() -> NoteTestView {
        button(ToolbarLocators.Buttons.openNoteButton.accessibilityIdentifier).clickOnHittable()
        let cardView = NoteTestView()
        cardView.waitForCardViewToLoad()
        return cardView
    }
    
    func getNumberOfTabs(wait: Bool = true) -> Int {
        return getTabs(wait: wait).count
    }

    func getNumberOfWebViewInMemory() -> Int {
        UITestsMenuBar().showWebViewCount()
        let element = app.staticTexts.element(matching: NSPredicate(format: "value BEGINSWITH 'WebViews alives:'")).firstMatch
        var intValue: Int?
        if let value = self.getElementStringValue(element: element).split(separator: ":").last {
            intValue = Int(value)
        }
        app.dialogs.buttons.firstMatch.click()
        return intValue ?? -1
    }
    
    func getTabByIndex(index: Int) -> XCUIElement {
        getTabs().element(boundBy: index)
    }
    
    func focusTabByIndex(index: Int) -> XCUIElement {
        let tab = getTabByIndex(index: index)
        waitForIsHittable(tab)
        getCenterOfElement(element: tab).hover()
        return tab
    }
    
    @discardableResult
    func activateSearchFieldFromTab(index: Int) -> OmniBoxTestView {
        let tab = getTabByIndex(index: index)
        tab.tapInTheMiddle()
        return OmniBoxTestView()
    }
    
    func getTabURLElementByIndex(index: Int) -> XCUIElement {
        return focusTabByIndex(index: index).staticTexts[WebViewLocators.Tabs.tabURL.accessibilityIdentifier].firstMatch
    }

    func getTabUrlAtIndex(index: Int) -> String {
        return self.getElementStringValue(element:  getTabURLElementByIndex(index: index))
    }
    
    func waitForTabUrlAtIndexToEqual(index: Int, expectedString: String) -> Bool {
        return waitForStringValueEqual(expectedString, getTabURLElementByIndex(index: index))
    }
    
    func waitForTabTitleToEqual(index: Int, expectedString: String) -> Bool {
        return waitForStringValueEqual(expectedString, getBrowserTabTitleElements()[index])
    }
    
    func waitForTabTitleToContain(index: Int, expectedString: String) -> Bool {
        return waitForStringValueContain(expectedString, getBrowserTabTitleElements()[index])
    }
    
    func waitForPublishedNoteToLoad(noteName: String) -> Bool {
        return app.windows.scrollViews.webViews["\(noteName) - beam"].waitForExistence(timeout: implicitWaitTimeout)
    }
    
    func waitForWebViewToLoad() -> Bool {
        return app.windows.scrollViews.webViews.firstMatch.waitForExistence(timeout: implicitWaitTimeout)
    }

    private let tabPredicate = NSPredicate(format: "identifier BEGINSWITH '\(WebViewLocators.Tabs.tabPrefix.accessibilityIdentifier)'")
    func getAnyTab() -> XCUIElement {
        app.groups.matching(tabPredicate).firstMatch
    }
    
    func getTabs(wait: Bool = true) -> XCUIElementQuery {
        if wait {
            _ = getAnyTab().waitForExistence(timeout: BaseTest.implicitWaitTimeout)
        }
        return app.groups.matching(tabPredicate)
    }

    func getNumberOfWindows() -> Int {
        self.app.windows.count
    }
    
    @discardableResult
    func closeTab() -> WebTestView {
        shortcutsHelper.shortcutActionInvoke(action: .closeTab)
        return self
    }
    
    @discardableResult
    func dragDropTab(draggedTabIndexFromSelectedTab: Int, destinationTabIndexFromSelectedTab: Int) -> WebTestView {
        //Important! Counting starts form the next of selected tab
        self.getTabByIndex(index: draggedTabIndexFromSelectedTab).click(forDuration: self.defaultPressDurationSeconds, thenDragTo: self.getTabByIndex(index: destinationTabIndexFromSelectedTab))
        return self
    }
    
    func scrollDown(_ numberOfTimes : Int = 1) {
        for _ in 1...numberOfTimes {
            self.app.webViews.firstMatch.scroll(byDeltaX: 0, deltaY: -200)
        }
    }
    
    func scrollUp(_ numberOfTimes : Int = 1) {
        for _ in 1...numberOfTimes {
            self.app.webViews.firstMatch.scroll(byDeltaX: 0, deltaY: 200)
        }
    }
    
    func isGoogleSearchTabOpened() -> Bool {
        return image("Google").waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func getPrintPopupWindow() -> XCUIElement {
        return app.dialogs["Print"].staticTexts["Print"]
    }
    
    @discardableResult
    func cancelPDFPrintAction() -> WebTestView {
        app.splitGroups.buttons["Cancel"].tapInTheMiddle()
        return self
    }
    
    func getPDFPrintButton() -> XCUIElement {
        return image(WebViewLocators.PDFElements.printButton.accessibilityIdentifier)
    }
    
    func getPDFDownloadButton() -> XCUIElement {
        return image(WebViewLocators.PDFElements.downloadButton.accessibilityIdentifier)
    }
    
    func getPDFZoomInButton() -> XCUIElement {
        return image(WebViewLocators.PDFElements.zoomInButton.accessibilityIdentifier)
    }
    
    func getPDFZoomOutButton() -> XCUIElement {
        return image(WebViewLocators.PDFElements.zoomOutButton.accessibilityIdentifier)
    }
    
    func getCurrentPDFZoomRatio() -> String {
        return getElementStringValue(element: staticText(WebViewLocators.PDFElements.zoomRatio.accessibilityIdentifier))
    }
    
    func browseHistoryForwardButtonClick() -> WebTestView {
        button(WebViewLocators.Buttons.goForwardButton.accessibilityIdentifier).tapInTheMiddle()
        return WebTestView()
    }
    
    func browseHistoryBackButtonClick() -> WebTestView {
        button(WebViewLocators.Buttons.goBackButton.accessibilityIdentifier).tapInTheMiddle()
        return WebTestView()
    }
    
    func activateAndWaitForSearchFieldToEqual(_ expectedUrl: String, tabIndex: Int = 0) -> Bool {
        return self.activateSearchFieldFromTab(index:tabIndex).waitForSearchFieldValueToEqual(expectedValue: expectedUrl)
    }

}
