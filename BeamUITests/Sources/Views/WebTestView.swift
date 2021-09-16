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
        staticText(WebViewLocators.Buttons.destinationCard.accessibilityIdentifier).click()
        searchField(WebViewLocators.SearchFields.destinationCardSearchField.accessibilityIdentifier).typeText(title)
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'autocompleteResult-selected-'")
        app.otherElements.matching(predicate).firstMatch.click()
        }
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
        WaitHelper().waitFor(WaitHelper.PredicateFormat.isHittable.rawValue,  button(OmniBarLocators.Buttons.openCardButton.accessibilityIdentifier))
        button(OmniBarLocators.Buttons.openCardButton.accessibilityIdentifier).click()
        return CardTestView()
    }
    
    func getNumberOfTabs() -> Int {
        _ = group(WebViewLocators.Images.browserTabBar.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        return app.groups.matching(identifier:WebViewLocators.Images.browserTabBar.accessibilityIdentifier).count
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
