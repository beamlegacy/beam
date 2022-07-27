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
        let element = staticText(WebViewLocators.Buttons.destinationNote.accessibilityIdentifier)
        _ = element.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return element
    }
    
    func getDestinationNoteTitle() -> String {
        return getDestinationNoteElement().getStringValue()
    }
    
    func getBrowserTabTitleValueByIndex(index: Int) -> String {
        return getBrowserTabTitleElements()[index].getStringValue()
    }
    
    func getBrowserTabTitleElements() -> [XCUIElement] {
        return app.windows.staticTexts.matching(identifier: WebViewLocators.Tabs.tabTitle.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    @discardableResult
    func openAllNotesMenu() -> AllNotesTestView {
        button(ToolbarLocators.Buttons.noteSwitcherAllNotes.accessibilityIdentifier).clickOnExistence()
        return AllNotesTestView()
    }
    
    func searchForNoteByTitle(_ title: String) {
        XCTContext.runActivity(named: "Search for '\(title)' note in notes search drop-down") {_ in
        self.getDestinationNoteElement().clickOnHittable()
        searchField(WebViewLocators.SearchFields.destinationNoteSearchField.accessibilityIdentifier).typeText(title)
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'autocompleteResult-selected-'")
        app.links.matching(predicate).firstMatch.clickOnExistence()
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
        let noteCreationElement = app.links.matching(predicate).firstMatch
        //Try out to replace additional waiting
        //XCTAssertTrue(noteCreationElement.waitForExistence(timeout: BaseTest.minimumWaitTimeout), "\(searchText) is NOT in the create note autocomplete result")
        noteCreationElement.clickOnExistence()
        return NoteTestView()
        }
    }
    
    @discardableResult
    func openDestinationNote() -> NoteTestView {
        button(ToolbarLocators.Buttons.openNoteButton.accessibilityIdentifier).clickOnHittable()
        let noteView = NoteTestView()
        noteView.waitForNoteViewToLoad()
        return noteView
    }
    
    func getNumberOfTabs(wait: Bool = true) -> Int {
        return getTabs(wait: wait).count
    }

    func getNumberOfUnpinnedTabs(wait: Bool = true) -> Int {
        return getTabs(wait: wait, pinned: false).count
    }
    
    func getNumberOfPinnedTabs(wait: Bool = true) -> Int {
        return getTabs(wait: wait, pinned: true).count
    }

    func getNumberOfWebViewInMemory() -> Int {
        uiMenu.showWebViewCount()
        _ = AlertTestView().isAlertDialogDisplayed()
        let element = app.staticTexts.element(matching: NSPredicate(format: "value BEGINSWITH 'WebViews alives:'")).firstMatch
        var intValue: Int?
        if let value = element.getStringValue().split(separator: ":").last {
            intValue = Int(value)
        }
        app.dialogs.buttons.firstMatch.clickOnExistence()
        return intValue ?? -1
    }
    
    func getTabByIndex(index: Int) -> XCUIElement {
        getTabs().element(boundBy: index)
    }
    
    func getPinnedTabByIndex(index: Int) -> XCUIElement {
        getTabs(pinned: true).element(boundBy: index)
    }
    
    func focusTabByIndex(index: Int, isPinnedTab: Bool = false) -> XCUIElement {
        let tab: XCUIElement
        if isPinnedTab {
            tab = getPinnedTabByIndex(index: index)
        } else {
            tab = getTabByIndex(index: index)
        }
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
        return getTabURLElementByIndex(index: index).getStringValue()
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
        waitForWebViewToLoad()
        return app.windows.scrollViews.webViews["\(noteName) - beam"].waitForExistence(timeout: implicitWaitTimeout)
    }
    
    @discardableResult
    func waitForWebViewToLoad() -> Bool {
        return app.windows.scrollViews.webViews.firstMatch.waitForExistence(timeout: implicitWaitTimeout)
    }

    private let anyTabPredicate = NSPredicate(format: "identifier BEGINSWITH '\(WebViewLocators.Tabs.tabPrefix.accessibilityIdentifier)'")
    func getAnyTab() -> XCUIElement {
        app.groups.matching(anyTabPredicate).firstMatch
    }

    private let tabUnpinnedPredicate = NSPredicate(format: """
        identifier BEGINSWITH '\(WebViewLocators.Tabs.tabPrefix.accessibilityIdentifier)' \
        && NOT (identifier BEGINSWITH '\(WebViewLocators.Tabs.tabPinnedPrefix.accessibilityIdentifier)')
    """)
    func getAnyUnpinnedTab() -> XCUIElement {
        app.groups.matching(tabUnpinnedPredicate).firstMatch
    }
        
    private let tabPinnedPredicate = NSPredicate(format: "identifier BEGINSWITH '\(WebViewLocators.Tabs.tabPinnedPrefix.accessibilityIdentifier)'")
    func getAnyPinnedTab() -> XCUIElement {
        app.groups.matching(tabPinnedPredicate).firstMatch
    }

    /// use pinned: nil to get any tabs
    func getTabs(wait: Bool = true, pinned: Bool? = nil) -> XCUIElementQuery {
        if pinned == true {
            if wait {
                _ = getAnyPinnedTab().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
            }
            return app.groups.matching(tabPinnedPredicate)
        } else if pinned == false {
            if wait {
                _ = getAnyUnpinnedTab().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
            }
            return app.groups.matching(tabUnpinnedPredicate)
        } else {
            if wait {
                _ = getAnyTab().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
            }
            return app.groups.matching(anyTabPredicate)
        }
    }

    func getNumberOfWindows() -> Int {
        return self.app.windows.count
    }
    
    @discardableResult
    func closeTab() -> WebTestView {
        shortcutHelper.shortcutActionInvoke(action: .closeTab)
        return self
    }
    
    @discardableResult
    func dragDropTab(draggedTabIndexFromSelectedTab: Int, destinationTabIndexFromSelectedTab: Int) -> WebTestView {
        //Important! Counting starts from the next of selected tab
        self.getTabByIndex(index: draggedTabIndexFromSelectedTab).clickForDurationThenDragToInTheMiddle(forDuration: self.defaultPressDurationSeconds, thenDragTo: self.getTabByIndex(index: destinationTabIndexFromSelectedTab))
        return self
    }
    
    @discardableResult
    func dragTabOutOfTheGroup(tabIndex: Int) -> WebTestView {
        self.getTabByIndex(index: tabIndex).clickForDurationThenDragToInTheMiddle(forDuration: self.defaultPressDurationSeconds, thenDragTo: self.button(WebViewLocators.Buttons.openOmnibox.accessibilityIdentifier))
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
        return button(WebViewLocators.PDFElements.downloadButton.accessibilityIdentifier)
    }
    
    func getPDFZoomInButton() -> XCUIElement {
        return image(WebViewLocators.PDFElements.zoomInButton.accessibilityIdentifier)
    }
    
    func getPDFZoomOutButton() -> XCUIElement {
        return image(WebViewLocators.PDFElements.zoomOutButton.accessibilityIdentifier)
    }
    
    func getCurrentPDFZoomRatio() -> String {
        return staticText(WebViewLocators.PDFElements.zoomRatio.accessibilityIdentifier).firstMatch.getStringValue()
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
    
    @discardableResult
    func openTabMenu(tabIndex: Int = 0, isPinnedTab: Bool = false) -> WebTestView {
        self.focusTabByIndex(index:tabIndex, isPinnedTab: isPinnedTab).rightClickInTheMiddle()
        return self
    }

    func selectTabMenuItem(_ menuAction: WebViewLocators.MenuItem) {
        menuItem(menuAction.accessibilityIdentifier).tapInTheMiddle()
    }

}
