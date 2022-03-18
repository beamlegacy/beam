//
//  Links.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation
import XCTest

class LinksTests: BaseTest {
    
    let cardName1 = "Note Link 1"
    let cardName2 = "Note Link 2"
    let todayCardNameCreationViewFormat = DateHelper().getTodaysDateString(.cardViewCreation)
    let todayCardNameCreationViewFormatWithout0InDays = DateHelper().getTodaysDateString(.cardViewCreationNoZeros)
    let todayCardNameTitleViewFormat = DateHelper().getTodaysDateString(.cardViewTitle)
    let shortcutsHelper = ShortcutsHelper()
    let waitHelper = WaitHelper()
    
    var cardView: CardTestView?
    
    private func createCardsAndLinkThem() -> CardTestView {
        let journalView = launchApp()
        step("Given I create 2 notes"){
            journalView.createCardViaOmniboxSearch(cardName1)
            cardView = journalView.createCardViaOmniboxSearch(cardName2)
        }

        
        step("Then I link note 2 to note 1"){
            cardView!.createBiDiLink(cardName1).openBiDiLink(0)
        }
        
        return cardView!
    }
    
    func testCreateCardLink()  {
        cardView = createCardsAndLinkThem()
        
        step("Then Note with links is correctly created"){
            XCTAssertEqual(cardView!.getLinksNamesNumber(), 1)
            XCTAssertEqual(cardView!.getLinksContentNumber(), 1)
            XCTAssertEqual(cardView!.getLinkNameByIndex(0), cardName2)
            XCTAssertEqual(cardView!.getLinkContentByIndex(0), cardName1 + " ") //looks like a bug
            cardView!.assertLinksCounterTitle(expectedNumber: 1)
        }

        step("And I can navigate to a note by Link both sides"){
            cardView!.openLinkByIndex(0)
            XCTAssertEqual(cardView!.getLinksNamesNumber(), 0)
            cardView!.openBiDiLink(0)
            XCTAssertEqual(cardView!.getLinksNamesNumber(), 1)
            XCTAssertEqual(cardView!.getLinkContentByIndex(0), cardName1 + " ")
        }

    }
    
    func testCardLinkDeletion() {
        cardView = createCardsAndLinkThem()
        
        step("When I delete the link between \(cardName2) and \(cardName1)"){
            cardView!.getFirstLinksContentElement().tapInTheMiddle()
            shortcutsHelper.shortcutActionInvoke(action: .selectAll)
            cardView!.typeKeyboardKey(.delete)
        }

        step("When I open \(cardName2)"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
        }
        
        step("Then note 2 has no links available"){
            XCTAssertEqual(cardView!.getCardNoteValueByIndex(0), emptyString)
        }
        
        step("Given I open \(cardName1) and I link \(cardName2)"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
            cardView!.createBiDiLink(cardName2)
        }

        step("Given I refresh the view switching notes"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
            XCTAssertEqual(cardView!.getLinksNamesNumber(), 1)
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
        }

        step("When I delete the link between \(cardName2) and \(cardName1)"){
            cardView!.getCardNoteElementByIndex(0).tapInTheMiddle()
            cardView!.typeKeyboardKey(.leftArrow)
            cardView!.typeKeyboardKey(.delete)
        }

        step("Then note 2 has no links available"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
            XCTAssertEqual(cardView!.getCardNoteValueByIndex(0), emptyString)
        }
        
        step("Given I link \(cardName1) and I link \(cardName2)"){
            cardView!.createBiDiLink(cardName1)
        }
        
        step("Given I refresh the view switching notes"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
            XCTAssertEqual(cardView!.getLinksNamesNumber(), 1)
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
        }
        
        step("When I delete note 1"){
            cardView!.clickDeleteButton().confirmDeletion()
        }
        
        step("Then note 2 has no links available"){
            XCTAssertTrue(cardView!.waitForCardToOpen(cardTitle: cardName1), "\(cardName1) note is failed to load")
            XCTAssertEqual(cardView!.getLinksNamesNumber(), 0)
        }

    }
    
    func testCardLinkTitleEditing() throws {
        let textToType = " some text"
        let renamingErrorHandling = " Some Text"
        cardView = createCardsAndLinkThem()
        
        step("When I change \(cardName1) name to \(cardName1)\(textToType)"){
            cardView!.makeCardTitleEditable().typeText(textToType)
            cardView!.typeKeyboardKey(.enter)
        }

        let expectedEditedName1 = cardName1 + textToType + " "

        step("Then note name changes are applied in links for note 1"){
            XCTAssertEqual(cardView!.getLinksNamesNumber(), 1)
            XCTAssertEqual(cardView!.getLinksContentNumber(), 1)
            XCTAssertEqual(cardView!.getLinkNameByIndex(0), cardName2)
            XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedEditedName1, cardView!.getLinkContentElementByIndex(0), minimumWaitTimeout), "\(cardView!.getLinkContentByIndex(0)) is not equal to \(expectedEditedName1)")
        }
       
        step("And note name changes are applied for note 2 note"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
            XCTAssertEqual(cardView!.getNumberOfVisibleNotes(), 1)
            XCTAssertEqual(cardView!.getCardNoteValueByIndex(0), expectedEditedName1)
        }

        step("When I change \(cardName2) name to \(cardName2)\(textToType)"){
            cardView!.makeCardTitleEditable().typeText(textToType)
            cardView!.typeKeyboardKey(.enter)
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1 + textToType)
        }

        step("Then note name changes are applied in links for note 1"){
            XCTAssertEqual(cardView!.getLinksNamesNumber(), 1)
            XCTAssertEqual(cardView!.getLinksContentNumber(), 1)
            XCTAssertEqual(cardView!.getLinkNameByIndex(0), cardName2 + renamingErrorHandling)
            XCTAssertEqual(cardView!.getLinkContentByIndex(0), expectedEditedName1)
        }

    }
    
    func testLinksSectionBreadcrumbs() throws {
        cardView = createCardsAndLinkThem()
        let additionalNote = "Level1"
        let editedValue = "Level0"

        step("Then by default there is no breadcrumb available"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
            XCTAssertFalse(cardView!.waitForBreadcrumbs(), "Breadcrumbs are available though shouldn't be")
        }

        step("When I create indentation level for the links"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
                .typeKeyboardKey(.upArrow)
            cardView!.app.typeText(additionalNote)
            cardView!.typeKeyboardKey(.enter)
            cardView!.typeKeyboardKey(.tab)
        }

        step("Then the breadcrumb appears in links section"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
            XCTAssertTrue(cardView!.waitForBreadcrumbs(), "Breadcrumbs didn't load/appear")
            XCTAssertEqual(cardView!.getBreadCrumbElementsNumber(), 1)
            XCTAssertEqual(cardView!.getBreadCrumbTitleByIndex(0), additionalNote)
        }

        
        step("When I edit parent of indentation level"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2).getCardNoteElementByIndex(0).tapInTheMiddle()
            cardView!.typeKeyboardKey(.delete, 1)
            cardView!.app.typeText("0")
        }

        step("Then breadcrumb title is changed in accordance to previous changes"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
            XCTAssertTrue(cardView!.waitForBreadcrumbs(), "Breadcrumbs didn't load/appear")
            XCTAssertEqual(cardView!.getBreadCrumbElementsNumber(), 1)
            XCTAssertEqual(cardView!.getBreadCrumbTitleByIndex(0), editedValue)
        }

        
        step("When delete indentation level"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2).getCardNoteElementByIndex(1).tapInTheMiddle()
            shortcutsHelper.shortcutActionInvoke(action: .beginOfLine)
            cardView!.typeKeyboardKey(.delete)
            cardView!.typeKeyboardKey(.space)
        }
        
        step("Then there are no breadcrumbs in links section"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
            XCTAssertFalse(cardView!.waitForBreadcrumbs(), "Breadcrumbs are available though shouldn't be")
        }

    }
    
    func SKIPtestLinksIndentationLevels() throws {
        try XCTSkipIf(true, "WIP")
    }
    
}
