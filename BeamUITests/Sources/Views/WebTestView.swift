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
    
    func getDestinationCardElement() -> XCUIElement {
        let element = staticText(WebViewLocators.Buttons.destinationCard.accessibilityIdentifier)
        _ = element.waitForExistence(timeout: minimumWaitTimeout)
        return element
    }
    
    func getDestinationCardTitle() -> String {
        return getElementStringValue(element: getDestinationCardElement())
    }
    
    func getBrowserTabTitleValueByIndex(index: Int) -> String {
        return getElementStringValue(element: getBrowserTabTitleElements()[index])
    }
    
    func getBrowserTabTitleElements() -> [XCUIElement] {
        return app.windows.staticTexts.matching(identifier: WebViewLocators.Tabs.tabTitle.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    @discardableResult
    func openAllCardsMenu() -> AllCardsTestView {
        button(ToolbarLocators.Buttons.cardSwitcherAllCards.accessibilityIdentifier).click()
        return AllCardsTestView()
    }
    
    func searchForCardByTitle(_ title: String) {
        XCTContext.runActivity(named: "Search for '\(title)' note in notes search drop-down") {_ in
        self.getDestinationCardElement().clickOnHittable()
        searchField(WebViewLocators.SearchFields.destinationCardSearchField.accessibilityIdentifier).typeText(title)
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'autocompleteResult-selected-'")
        app.otherElements.matching(predicate).firstMatch.click()
        }
    }
    
    func openDestinationCardSearch() -> XCUIElement {
        let element = self.getDestinationCardElement()
        element.clickOnHittable()
        return element
    }
    
    @discardableResult
    func selectCreateCard(_ searchText: String) -> CardTestView {
        XCTContext.runActivity(named: "Click on proposed New note option for '\(searchText)' search keyword") {_ in
        // The mouse could overlap the autocomplete result so we should also match on "selected" results
        let predicate = NSCompoundPredicate(
            type: .or,
            subpredicates: [
                NSPredicate(format: "identifier BEGINSWITH 'autocompleteResult-" + searchText + "-createNote'"),
                NSPredicate(format: "identifier BEGINSWITH 'autocompleteResult-selected-" + searchText + "-createNote'")
            ]
        )
        let cardCreationElement = app.otherElements.matching(predicate).firstMatch
        //Try out to replace additional waiting
        //XCTAssertTrue(cardCreationElement.waitForExistence(timeout: minimumWaitTimeout), "\(searchText) is NOT in the create card autocomplete result")
        cardCreationElement.clickOnExistence()
        return CardTestView()
        }
    }
    
    @discardableResult
    func openDestinationCard() -> CardTestView {
        button(ToolbarLocators.Buttons.openCardButton.accessibilityIdentifier).clickOnHittable()
        let cardView = CardTestView()
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
        WaitHelper().waitForIsHittable(tab)
        getCenterOfElement(element: tab).hover()
        return tab
    }
    
    @discardableResult
    func activateSearchFieldFromTab(index: Int) -> OmniBoxTestView {
        let tab = getTabByIndex(index: index)
        if !WaitHelper().waitForIsHittable(tab) {
            //button(WebViewLocators.Buttons.goToJournalButton.accessibilityIdentifier).hover()
            //XCTAssertTrue(WaitHelper().waitForIsHittable(tab), "Timeout waiting for tab to be hittable")
            shortcutsHelper.shortcutActionInvoke(action: .openLocation)
            sleep(1000)
            shortcutsHelper.shortcutActionInvoke(action: .openLocation)
        }
        tab.hover()
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
        return WaitHelper().waitForStringValueEqual(expectedString, getTabURLElementByIndex(index: index))
    }
    
    func waitForTabTitleToEqual(index: Int, expectedString: String) -> Bool {
        return WaitHelper().waitForStringValueEqual(expectedString, getBrowserTabTitleElements()[index])
    }

    private let tabPredicate = NSPredicate(format: "identifier BEGINSWITH '\(WebViewLocators.Tabs.tabPrefix.accessibilityIdentifier)'")
    func getAnyTab() -> XCUIElement {
        app.groups.matching(tabPredicate).firstMatch
    }
    
    func getTabs(wait: Bool = true) -> XCUIElementQuery {
        if wait {
            _ = getAnyTab().waitForExistence(timeout: implicitWaitTimeout)
        }
        return app.groups.matching(tabPredicate)
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
        return image("Google").waitForExistence(timeout: minimumWaitTimeout)
    }

}
