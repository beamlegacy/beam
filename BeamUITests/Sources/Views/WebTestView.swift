//
//  TabsView.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class WebTestView: BaseView {
    
    func getDestinationCardElement() -> XCUIElement {
        let element = staticText(WebViewLocators.Buttons.destinationCard.accessibilityIdentifier)
        _ = element.waitForExistence(timeout: minimumWaitTimeout)
        return element
    }
    
    func getDestinationCardTitle() -> String {
        return getElementStringValue(element: getDestinationCardElement())
    }
    
    @discardableResult
    func openAllCardsMenu() -> AllCardsTestView {
        button(JournalViewLocators.Buttons.allCardsMenuButton.accessibilityIdentifier).click()
        return AllCardsTestView()
    }
    
    func searchForCardByTitle(_ title: String) {
        XCTContext.runActivity(named: "Search for '\(title)' card in cards search drop-down") {_ in
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
        XCTContext.runActivity(named: "Click on proposed New card option for '\(searchText)' search keyword") {_ in
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'autocompleteResult-" + searchText + "-createCard'")
        let cardCreationElement = app.otherElements.matching(predicate).firstMatch
        //Try out to replace additional waiting
        //XCTAssertTrue(cardCreationElement.waitForExistence(timeout: minimumWaitTimeout), "\(searchText) is NOT in the create card autocomplete result")
        cardCreationElement.clickOnExistence()
        return CardTestView()
        }
    }
    
    @discardableResult
    func openDestinationCard() -> CardTestView {
        button(OmniBarLocators.Buttons.openCardButton.accessibilityIdentifier).clickOnHittable()
        let cardView = CardTestView()
        cardView.waitForCardViewToLoad()
        return cardView
    }
    
    func getNumberOfTabs() -> Int {
        return getTabs().count
    }

    func getNumberOfWebViewInMemory() -> Int {
        UITestsMenuBar().showWebViewCount()
        let element = app.staticTexts.element(matching: NSPredicate(format: "value BEGINSWITH 'WebViews alives:'")).firstMatch
        var intValue: Int?
        if let value = (element.value as? String)?.split(separator: ":").last {
            intValue = Int(value)
        }
        app.dialogs.buttons.firstMatch.click()
        return intValue ?? -1
    }
    
    func getTabByIndex(index: Int) -> XCUIElement {
        getTabs().element(boundBy: index)
    }
    
    func getTabs() -> XCUIElementQuery {
        _ = group(WebViewLocators.Images.browserTabBar.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        return app.groups.matching(identifier:WebViewLocators.Images.browserTabBar.accessibilityIdentifier)
    }
    
    @discardableResult
    func openTab() -> WebTestView {
        image(WebViewLocators.Buttons.newTabButton.accessibilityIdentifier).click()
        return self
    }
    
    @discardableResult
    func closeTab() -> WebTestView {
        app.groups.matching(identifier:WebViewLocators.Images.browserTabBar.accessibilityIdentifier).firstMatch.hover()
        app.images.matching(identifier: WebViewLocators.Buttons.closeTabButton.accessibilityIdentifier).firstMatch.click()
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
