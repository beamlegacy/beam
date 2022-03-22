//
//  References.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation
import XCTest

class ReferencesTests: BaseTest {
    
    let cardName1 = "Note Reference 1"
    let cardName2 = "Note Reference 2"
    let shortcutsHelper = ShortcutsHelper()
    var cardView: CardTestView?

    private func createCardsAndReferenceThem() -> CardTestView {
        let journalView = launchApp()
        
        step ("Given I create 2 notes"){
            journalView.createCardViaOmniboxSearch(cardName1)
            cardView = journalView.createCardViaOmniboxSearch(cardName2)
        }

        step ("Then I reference note 2 to note 1"){
            cardView!.createReference(cardName1)
        }
        
        return cardView!
    }
    
    func testCreateCardReference() {
        cardView = createCardsAndReferenceThem()
        cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)

        XCTAssertEqual(cardView!.getLinksNamesNumber(), 0) //Link ONLY
        XCTAssertEqual(cardView!.getLinksContentNumber(), 0)
        cardView!.assertReferenceCounterTitle(expectedNumber: 1)
        
        cardView!.expandReferenceSection()
        XCTAssertEqual(cardView!.getLinksNamesNumber(), 1) // Link and Reference
        XCTAssertEqual(cardView!.getLinksContentNumber(), 1)
        XCTAssertEqual(cardView!.getLinkNameByIndex(0), cardName2)
        XCTAssertEqual(cardView!.getLinkContentByIndex(0), cardName1)
        
        step ("Then I can navigate to a note by Reference to a source note"){
            cardView!.openLinkByIndex(0)
            XCTAssertEqual(cardView!.getNumberOfVisibleNotes(), 2)
            XCTAssertEqual(cardView!.getCardNoteValueByIndex(0), cardName1)
        }

        
    }
    
    func testReferenceDeletion() {
        cardView = createCardsAndReferenceThem()
        cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
            .expandReferenceSection()
        
        step ("When I delete the reference between \(cardName2) and \(cardName1)"){
            cardView!.getFirstLinksContentElement().tapInTheMiddle()
            shortcutsHelper.shortcutActionInvoke(action: .selectAll)
            cardView!.typeKeyboardKey(.delete)
        }

        
        step ("When I open \(cardName2)"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
        }

        step ("Then note 2 has no references available"){
            XCTAssertEqual(cardView!.getNumberOfVisibleNotes(), 2)
            XCTAssertEqual(cardView!.getCardNoteValueByIndex(0), emptyString)
        }

        
        step ("Given I open \(cardName1) and I reference \(cardName2)"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
            XCTAssertFalse(cardView!.doesReferenceSectionExist())
            cardView!.createReference(cardName2)
        }

        step ("Given I refresh the view switching notes"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
            XCTAssertTrue(cardView!.doesReferenceSectionExist())
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
        }

        step ("When I delete the reference between \(cardName2) and \(cardName1)"){
            cardView!.getCardNoteElementByIndex(0).tapInTheMiddle()
            shortcutsHelper.shortcutActionInvoke(action: .selectAll)
            cardView!.typeKeyboardKey(.delete)
        }

        step ("Then note 2 has no references available"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
            XCTAssertFalse(cardView!.doesReferenceSectionExist())
        }

        step ("Given I reference \(cardName1) and I reference \(cardName2)"){
            cardView!.createReference(cardName1)
        }

        step ("Given I refresh the view switching notes"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
            XCTAssertTrue(cardView!.doesReferenceSectionExist())
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
        }

        
        step ("When I delete note 1"){
            cardView!.clickDeleteButton().confirmDeletion()
        }
        
        step ("Then note 2 has no references available"){
            XCTAssertTrue(cardView!.waitForCardToOpen(cardTitle: cardName1), "\(cardName1) note is failed to load")
            XCTAssertFalse(cardView!.doesReferenceSectionExist())
        }

    }
    
    func testReferenceEditing() throws {
        let textToType = " some text"
        let renamedCard1 = cardName1 + textToType
        cardView = createCardsAndReferenceThem()
        BeamUITestsHelper(cardView!.app).tapCommand(.resizeWindowLandscape)
        cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
        
        step ("Given I rename note 1 to \(cardName1)\(textToType)"){
            cardView!.makeCardTitleEditable().typeText(textToType)
            cardView!.typeKeyboardKey(.enter)
        }

        step ("Then note 1 has no references available"){
            XCTAssertTrue(waitForDoesntExist(cardView!.getRefereceSectionCounterElement()))
        }
        
        step ("Given I rename the note in note 2 to \(renamedCard1)"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
                .getCardNoteElementByIndex(0)
                .clickOnExistence()
            cardView!.typeInCardNoteByIndex(noteIndex: 0, text: textToType)
        }

        step ("Then in note 1 all the reference appears again"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: renamedCard1)
            XCTAssertTrue(cardView!.doesReferenceSectionExist())
        }

        step ("When I change the reference text in note 1"){
            cardView!.expandReferenceSection()
                .getLinkContentElementByIndex(0)
                .clickOnExistence()
            cardView!.typeKeyboardKey(.delete, textToType.count)
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
        }

        step ("Then in note 2 the note is renamed as in note 1"){
            XCTAssertEqual(cardView!.getNumberOfVisibleNotes(), 2)
            XCTAssertEqual(cardView!.getCardNoteValueByIndex(0), cardName1)
        }

        step ("And in note 1 the reference is gone"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: renamedCard1)
            XCTAssertFalse(cardView!.doesReferenceSectionExist())
        }

    }
    
    func SKIPtestLinkReferecnes() throws {
        try XCTSkipIf(true, "Link and Link All buttons are not accessible")
        let secondReference = "\(cardName1) second REF"
        let thirdReference = "\(cardName1) THIRD_reference"
        cardView = createCardsAndReferenceThem()
        
        step ("Given I create reference \(secondReference) for note 2 and \(thirdReference) for note 3"){
            cardView!.typeInCardNoteByIndex(noteIndex: 1, text: secondReference)
            cardView!.typeKeyboardKey(.enter)
            cardView!.typeInCardNoteByIndex(noteIndex: 2, text: thirdReference)
        }

        
        step ("Given I open \(cardName1)"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
            cardView!.expandReferenceSection()
        }

        
        /*step ("When I click Link first reference"){
            
        }
        TBD once link button is accessible
        
        step ("Then "){
            
        }*/
                     
        step ("When I click Link All for remained references"){
            cardView!.expandReferenceSection()
                .linkAllReferences()
        }

        
        step ("Then the card has no references available"){
            XCTAssertTrue(waitForDoesntExist(cardView!.getRefereceSectionCounterElement()))
        }
    }
    
    func testReferencesSectionBreadcrumbs() throws {
        cardView = createCardsAndReferenceThem()
        let additionalNote = "Level1"
        let editedValue = "Level0"

        step ("Then by default there is no breadcrumb available"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
                .expandReferenceSection()
            XCTAssertFalse(cardView!.waitForBreadcrumbs(), "Breadcrumbs are available though shouldn't be")
        }

        step ("When I create indentation level for the reference"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2)
                .typeKeyboardKey(.upArrow)
            cardView!.app.typeText(additionalNote)
            cardView!.typeKeyboardKey(.enter)
            cardView!.typeKeyboardKey(.tab)
        }

        step ("Then the breadcrumb appears in references section"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
                .expandReferenceSection()
            XCTAssertTrue(cardView!.waitForBreadcrumbs(), "Breadcrumbs didn't load/appear")
            XCTAssertEqual(cardView!.getBreadCrumbElementsNumber(), 1)
            XCTAssertEqual(cardView!.getBreadCrumbTitleByIndex(0), additionalNote)
        }

        step ("When I edit parent of indentation level"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2).getCardNoteElementByIndex(0).tapInTheMiddle()
            cardView!.typeKeyboardKey(.delete, 1)
            cardView!.app.typeText("0")
        }

        step ("Then breadcrumb title is changed in accordance to previous changes"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
                .expandReferenceSection()
            XCTAssertTrue(cardView!.waitForBreadcrumbs(), "Breadcrumbs didn't load/appear")
            XCTAssertEqual(cardView!.getBreadCrumbElementsNumber(), 1)
            XCTAssertEqual(cardView!.getBreadCrumbTitleByIndex(0), editedValue)
        }

        step ("When delete indentation level"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName2).getCardNoteElementByIndex(1).tapInTheMiddle()
            shortcutsHelper.shortcutActionInvoke(action: .beginOfLine)
            cardView!.typeKeyboardKey(.delete)
            cardView!.typeKeyboardKey(.space)
        }

        step ("Then there are no breadcrumbs in reference section"){
            cardView!.openCardFromRecentsList(cardTitleToOpen: cardName1)
                .expandReferenceSection()
            XCTAssertFalse(cardView!.waitForBreadcrumbs(), "Breadcrumbs are available though shouldn't be")
        }

    }
    
    func SKIPtestReferencesIndentationLevels() throws {
        try XCTSkipIf(true, "WIP")
    }
}
