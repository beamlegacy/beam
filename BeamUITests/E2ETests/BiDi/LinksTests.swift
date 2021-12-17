//
//  Links.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation
import XCTest

class LinksTests: BaseTest {
    
    let cardName1 = "Card Link 1"
    let cardName2 = "Card Link 2"
    let todayCardNameCreationViewFormat = DateHelper().getTodaysDateString(.cardViewCreation)
    let todayCardNameCreationViewFormatWithout0InDays = DateHelper().getTodaysDateString(.cardViewCreationNoZeros)
    let todayCardNameTitleViewFormat = DateHelper().getTodaysDateString(.cardViewTitle)
    let shortcutsHelper = ShortcutsHelper()
    let waitHelper = WaitHelper()
    
    private func createCardsAndLinkThem() -> CardTestView {
        let journalView = launchApp()
        
        testRailPrint("Given I create 2 cards")
        journalView.createCardViaOmnibarSearch(cardName1)
        let cardView = journalView.createCardViaOmnibarSearch(cardName2)
        
        testRailPrint("Then I link card 2 to card 1")
        cardView.createBiDiLink(cardName1).openBiDiLink(0)
        
        return cardView
    }
    
    func testCreateCardLink()  {
        let cardView = createCardsAndLinkThem()
        XCTAssertEqual(cardView.getLinksNamesNumber(), 1)
        XCTAssertEqual(cardView.getLinksContentNumber(), 1)
        XCTAssertEqual(cardView.getLinkNameByIndex(0), cardName2)
        XCTAssertEqual(cardView.getLinkContentByIndex(0), cardName1 + " ") //looks like a bug
        cardView.assertLinksCounterTitle(expectedNumber: 1)

        testRailPrint("Then I can navigate to a card by Link both sides")
        cardView.openLinkByIndex(0)
        XCTAssertEqual(cardView.getLinksNamesNumber(), 0)
        cardView.openBiDiLink(0)
        XCTAssertEqual(cardView.getLinksNamesNumber(), 1)
        XCTAssertEqual(cardView.getLinkContentByIndex(0), cardName1 + " ")
    }
    
    func testCardLinkDeletion() {
        let cardView = createCardsAndLinkThem()
        
        testRailPrint("When I delete the link between \(cardName2) and \(cardName1)")
        cardView.getLinksContentElement()[0].tapInTheMiddle()
        shortcutsHelper.shortcutActionInvoke(action: .selectAll)
        cardView.typeKeyboardKey(.delete)
        
        testRailPrint("When I open \(cardName2)")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
        
        testRailPrint("Then card 2 has no links available")
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), emptyString)
        
        testRailPrint("Given I open \(cardName1) and I link \(cardName2)")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
        cardView.createBiDiLink(cardName2)
        
        testRailPrint("Given I refresh the view switching cards")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
        XCTAssertEqual(cardView.getLinksNamesNumber(), 1)
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
        
        testRailPrint("When I delete the link between \(cardName2) and \(cardName1)")
        cardView.getCardNoteElementByIndex(0).tapInTheMiddle()
        cardView.typeKeyboardKey(.leftArrow)
        cardView.typeKeyboardKey(.delete)
        
        testRailPrint("Then card 2 has no links available")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), emptyString)
        
        testRailPrint("Given I link \(cardName1) and I link \(cardName2)")
        cardView.createBiDiLink(cardName1)
        
        testRailPrint("Given I refresh the view switching cards")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
        XCTAssertEqual(cardView.getLinksNamesNumber(), 1)
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
        
        testRailPrint("When I delete card 1")
        cardView.clickDeleteButton().confirmDeletion()
        
        testRailPrint("Then card 2 has no links available")
        XCTAssertTrue(cardView.waitForCardToOpen(cardTitle: cardName1), "\(cardName1) card is failed to load")
        XCTAssertEqual(cardView.getLinksNamesNumber(), 0)
    }
    
    func testCardLinkTitleEditing() throws {
        let textToType = " some text"
        let renamingErrorHandling = " Some Text"
        let cardView = createCardsAndLinkThem()
        
        testRailPrint("When I change \(cardName1) name to \(cardName1)\(textToType)")
        cardView.makeCardTitleEditable().typeText(textToType)
        cardView.typeKeyboardKey(.enter)
        
        testRailPrint("Then card name changes are applied in links for card 1")
        let expectedEditedName1 = cardName1 + textToType + " "
        XCTAssertEqual(cardView.getLinksNamesNumber(), 1)
        XCTAssertEqual(cardView.getLinksContentNumber(), 1)
        XCTAssertEqual(cardView.getLinkNameByIndex(0), cardName2)
        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedEditedName1, cardView.getLinkContentElementByIndex(0), minimumWaitTimeout), "\(cardView.getLinkContentByIndex(0)) is not equal to \(expectedEditedName1)")
       
        testRailPrint("Then card name changes are applied for card 2 note")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
        XCTAssertEqual(cardView.getNumberOfVisibleNotes(), 1)
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), expectedEditedName1)
        
        testRailPrint("When I change \(cardName2) name to \(cardName2)\(textToType)")
        cardView.makeCardTitleEditable().typeText(textToType)
        cardView.typeKeyboardKey(.enter)
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1 + textToType)
        
        testRailPrint("Then card name changes are applied in links for card 1")
        XCTAssertEqual(cardView.getLinksNamesNumber(), 1)
        XCTAssertEqual(cardView.getLinksContentNumber(), 1)
        XCTAssertEqual(cardView.getLinkNameByIndex(0), cardName2 + renamingErrorHandling)
        XCTAssertEqual(cardView.getLinkContentByIndex(0), expectedEditedName1)
    }
    
    func testLinksSectionBreadcrumbs() throws {
        let cardView = createCardsAndLinkThem()
        let additionalNote = "Level1"
        let editedValue = "Level0"

        testRailPrint("Then by default there is no breadcrumb available")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
        XCTAssertFalse(cardView.waitForBreadcrumbs(), "Breadcrumbs are available though shouldn't be")
        
        testRailPrint("When I create indentation level for the links")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
            .typeKeyboardKey(.upArrow)
        cardView.app.typeText(additionalNote)
        cardView.typeKeyboardKey(.enter)
        cardView.typeKeyboardKey(.tab)
        
        testRailPrint("Then the breadcrumb appears in links section")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
        XCTAssertTrue(cardView.waitForBreadcrumbs(), "Breadcrumbs didn't load/appear")
        XCTAssertEqual(cardView.getBreadCrumbElementsNumber(), 1)
        XCTAssertEqual(cardView.getBreadCrumbTitleByIndex(0), additionalNote)
        
        testRailPrint("When I edit parent of indentation level")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2).getCardNoteElementByIndex(0).tapInTheMiddle()
        cardView.typeKeyboardKey(.delete, 1)
        cardView.app.typeText("0")
        
        testRailPrint("Then breadcrumb title is changed in accordance to previous changes")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
        XCTAssertTrue(cardView.waitForBreadcrumbs(), "Breadcrumbs didn't load/appear")
        XCTAssertEqual(cardView.getBreadCrumbElementsNumber(), 1)
        XCTAssertEqual(cardView.getBreadCrumbTitleByIndex(0), editedValue)
        
        testRailPrint("When delete indentation level")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2).getCardNoteElementByIndex(1).tapInTheMiddle()
        shortcutsHelper.shortcutActionInvoke(action: .beginOfLine)
        cardView.typeKeyboardKey(.delete)
        cardView.typeKeyboardKey(.space)
        
        testRailPrint("Then there are no breadcrumbs in links section")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
        XCTAssertFalse(cardView.waitForBreadcrumbs(), "Breadcrumbs are available though shouldn't be")
    }
    
    func testLinksIndentationLevels() throws {
        try XCTSkipIf(true, "WIP")
    }
    
}
