//
//  JournalView.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class JournalTestView: BaseView {
    
    func getHelpButton() -> XCUIElement {
        return staticText("HelpButton")
    }
    
    @discardableResult
    func openAllCardsMenu() -> AllCardsTestView {
        let allCardsMenuButton = staticText(JournalViewLocators.Buttons.allCardsMenuButton.accessibilityIdentifier)
        WaitHelper().waitFor(WaitHelper.PredicateFormat.isHittable.rawValue, allCardsMenuButton)
        allCardsMenuButton.click()
        return AllCardsTestView()
    }
    
    @discardableResult
    func openRecentCardByName(_ cardName: String) -> CardTestView {
        _ = staticText(cardName).waitForExistence(timeout: implicitWaitTimeout)
        staticText(cardName).click()
        return CardTestView()
    }
    
    @discardableResult
    func openHelpMenu() -> HelpTestView {
        getHelpButton().click()
        return HelpTestView()
    }
    
    @discardableResult
    func createCardViaOmnibarSearch(_ cardNameToBeCreated: String) -> CardTestView {
        return self.searchInOmniBar(cardNameToBeCreated, false).selectCreateCard(cardNameToBeCreated)
    }
    
    @discardableResult
    func scroll(_ numberOfScrolls: Int) -> JournalTestView {
        for _ in 0...numberOfScrolls {
            scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).scroll(byDeltaX: 0, deltaY: -1000)
        }
        return self
    }
    
    @discardableResult
    func getNoteByIndex(_ i: Int) -> XCUIElement {
        let index = i - 1
        return scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).children(matching: .textView).matching(identifier: CardViewLocators.TextFields.noteField.accessibilityIdentifier).element(boundBy: index)
    }
}
