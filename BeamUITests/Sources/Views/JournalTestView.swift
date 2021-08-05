//
//  JournalView.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation

class JournalTestView: BaseView {
    
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
    func createCardViaOmnibarSearch(_ cardNameToBeCreated: String) -> CardTestView {
        return self.searchInOmniBar(cardNameToBeCreated, false).selectCreateCard(cardNameToBeCreated)
    }
}
