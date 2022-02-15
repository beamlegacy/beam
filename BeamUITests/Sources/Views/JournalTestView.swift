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
        let allCardsMenuButton = button(ToolbarLocators.Buttons.cardSwitcherAllCards.accessibilityIdentifier)
        WaitHelper().waitFor(WaitHelper.PredicateFormat.isHittable.rawValue, allCardsMenuButton)
        allCardsMenuButton.click()
        return AllCardsTestView()
    }
    
    @discardableResult
    func openRecentCardByName(_ cardName: String) -> CardTestView {
        let button = app.buttons.matching(identifier: ToolbarLocators.Buttons.cardSwitcher.accessibilityIdentifier)
            .matching(NSPredicate(format: "value = '\(cardName)'")).firstMatch
        WaitHelper().waitFor(WaitHelper.PredicateFormat.isHittable.rawValue, button)
        button.click()
        return CardTestView()
    }
    
    @discardableResult
    func openHelpMenu() -> HelpTestView {
        getHelpButton().clickOnHittable()
        return HelpTestView()
    }
    
    @discardableResult
    func createCardViaOmniboxSearch(_ cardNameToBeCreated: String) -> CardTestView {
        searchInOmniBox(cardNameToBeCreated, false)
        app.typeKey(.enter, modifierFlags: .option)
        return CardTestView()
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
        return scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).children(matching: .textView).matching(identifier: CardViewLocators.TextFields.textNode.accessibilityIdentifier).element(boundBy: index)
    }
    
    @discardableResult
    func waitForJournalViewToLoad() -> JournalTestView {
        _ = scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        return self
    }
    
    func isJournalOpened() -> Bool {
        return scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).exists
    }
    
    func clickUpdateNow() -> UpdateTestView {
        self.staticText(JournalViewLocators.StaticTexts.updateNowButton.accessibilityIdentifier).clickOnExistence()
        return UpdateTestView()
    }
}
