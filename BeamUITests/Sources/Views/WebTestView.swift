//
//  TabsView.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class WebTestView: BaseView {
    
    @discardableResult
    func openAllCardsMenu() -> AllCardsTestView {
        button(JournalViewLocators.Buttons.allCardsMenuButton.accessibilityIdentifier).click()
        return AllCardsTestView()
    }
    
    func searchForCardByTitle(_ title: String) {
        XCTContext.runActivity(named: "Search for '\(title)' card in cards search drop-down") {_ in
        staticText(WebViewLocators.Buttons.destinationCard.accessibilityIdentifier).clickOnHittable()
        searchField(WebViewLocators.SearchFields.destinationCardSearchField.accessibilityIdentifier).typeText(title)
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'autocompleteResult-selected-'")
        app.otherElements.matching(predicate).firstMatch.click()
        }
    }
    
    func openDestinationCardSearch() -> XCUIElement {
        staticText(WebViewLocators.Buttons.destinationCard.accessibilityIdentifier).clickOnHittable()
        return staticText(WebViewLocators.Buttons.destinationCard.accessibilityIdentifier)
    }
    
    @discardableResult
    func selectCreateCard(_ searchText: String) -> CardTestView {
        XCTContext.runActivity(named: "Click on proposed New card option for '\(searchText)' search keyword") {_ in
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'autocompleteResult-" + searchText + "-createCard'")
        let cardCreationElement = app.otherElements.matching(predicate).firstMatch
        WaitHelper().waitFor(WaitHelper.PredicateFormat.isHittable.rawValue, cardCreationElement)
        cardCreationElement.click()
        return CardTestView()
        }
    }
    
    @discardableResult
    func openDestinationCard() -> CardTestView {
        button(OmniBarLocators.Buttons.openCardButton.accessibilityIdentifier).clickOnHittable()
        return CardTestView()
    }
    
    func getNumberOfTabs() -> Int {
        return getTabs().count
    }
    
    func getTab(number: Int) -> XCUIElement {
        getTabs().element(boundBy: number - 1)
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
}
