//
//  References.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation
import XCTest

class ReferencesTests: BaseTest {
    
    let cardName1 = "Card Reference 1"
    let cardName2 = "Card Reference 2"
    let shortcutsHelper = ShortcutsHelper()
    let waitHelper = WaitHelper()
    
    private func createCardsAndReferenceThem() -> CardTestView {
        let journalView = launchApp()
        
        testRailPrint("Given I create 2 cards")
        journalView.createCardViaOmniboxSearch(cardName1)
        let cardView = journalView.createCardViaOmniboxSearch(cardName2)
        
        testRailPrint("Then I reference card 2 to card 1")
        cardView.createReference(cardName1)
        
        return cardView
    }
    
    func testCreateCardReference() {
        let cardView = createCardsAndReferenceThem()
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)

        XCTAssertEqual(cardView.getLinksNamesNumber(), 0) //Link ONLY
        XCTAssertEqual(cardView.getLinksContentNumber(), 0)
        cardView.assertReferenceCounterTitle(expectedNumber: 1)
        
        cardView.expandReferenceSection()
        XCTAssertEqual(cardView.getLinksNamesNumber(), 1) // Link and Reference
        XCTAssertEqual(cardView.getLinksContentNumber(), 1)
        XCTAssertEqual(cardView.getLinkNameByIndex(0), cardName2)
        XCTAssertEqual(cardView.getLinkContentByIndex(0), cardName1)
        
        testRailPrint("Then I can navigate to a card by Reference to a source card")
        cardView.openLinkByIndex(0)
        XCTAssertEqual(cardView.getNumberOfVisibleNotes(), 2)
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), cardName1)
        
    }
    
    func testReferenceDeletion() {
        let cardView = createCardsAndReferenceThem()
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
            .expandReferenceSection()
        
        testRailPrint("When I delete the reference between \(cardName2) and \(cardName1)")
        cardView.getLinksContentElement()[0].tapInTheMiddle()
        shortcutsHelper.shortcutActionInvoke(action: .selectAll)
        cardView.typeKeyboardKey(.delete)
        
        testRailPrint("When I open \(cardName2)")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
        //cardView.expandReferenceSection()
        
        testRailPrint("Then card 2 has no references available")
        XCTAssertEqual(cardView.getNumberOfVisibleNotes(), 2)
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), emptyString)
        
        testRailPrint("Given I open \(cardName1) and I reference \(cardName2)")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
        XCTAssertFalse(cardView.doesReferenceSectionExist())
        cardView.createReference(cardName2)
        
        testRailPrint("Given I refresh the view switching cards")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
        XCTAssertTrue(cardView.doesReferenceSectionExist())
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
        
        testRailPrint("When I delete the reference between \(cardName2) and \(cardName1)")
        cardView.getCardNoteElementByIndex(0).tapInTheMiddle()
        shortcutsHelper.shortcutActionInvoke(action: .selectAll)
        cardView.typeKeyboardKey(.delete)
        
        testRailPrint("Then card 2 has no references available")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
        XCTAssertFalse(cardView.doesReferenceSectionExist())
        
        testRailPrint("Given I reference \(cardName1) and I reference \(cardName2)")
        cardView.createReference(cardName1)
        
        testRailPrint("Given I refresh the view switching cards")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
        XCTAssertTrue(cardView.doesReferenceSectionExist())
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
        
        testRailPrint("When I delete card 1")
        cardView.clickDeleteButton().confirmDeletion()
        
        testRailPrint("Then card 2 has no references available")
        XCTAssertTrue(cardView.waitForCardToOpen(cardTitle: cardName1), "\(cardName1) card is failed to load")
        XCTAssertFalse(cardView.doesReferenceSectionExist())
    }
    
    func testReferenceEditing() throws {
        let textToType = " some text"
        let renamedCard1 = cardName1 + textToType
        let cardView = createCardsAndReferenceThem()
        BeamUITestsHelper(cardView.app).tapCommand(.resizeWindowLandscape)
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
        
        testRailPrint("Given I rename card 1 to \(cardName1)\(textToType)")
        cardView.makeCardTitleEditable().typeText(textToType)
        cardView.typeKeyboardKey(.enter)
        
        testRailPrint("Then card 1 has no references available")
        XCTAssertTrue(waitHelper.waitForDoesntExist(cardView.getRefereceSectionCounterElement()))
        
        testRailPrint("Given I rename the note in card 2 to \(renamedCard1)")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
            .getCardNoteElementByIndex(0)
            .clickOnExistence()
        cardView.typeInCardNoteByIndex(noteIndex: 0, text: textToType)
        
        testRailPrint("Then in card 1 all the reference appears again")
        cardView.openCardFromRecentsList(cardTitleToOpen: renamedCard1)
        XCTAssertTrue(cardView.doesReferenceSectionExist())
        
        testRailPrint("When I change the reference text in card 1")
        cardView.expandReferenceSection()
            .getLinkContentElementByIndex(0)
            .clickOnExistence()
        cardView.typeKeyboardKey(.delete, textToType.count)
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
        
        testRailPrint("Then in card 2 the note is renamed as in card 1")
        XCTAssertEqual(cardView.getNumberOfVisibleNotes(), 2)
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), cardName1)
        
        testRailPrint("Then in card 1 the reference is gone")
        cardView.openCardFromRecentsList(cardTitleToOpen: renamedCard1)
        XCTAssertFalse(cardView.doesReferenceSectionExist())
    }
    
    func testLinkReferecnes() throws {
        try XCTSkipIf(true, "Link and Link All buttons are not accessible")
        let secondReference = "\(cardName1) second REF"
        let thirdReference = "\(cardName1) THIRD_reference"
        let cardView = createCardsAndReferenceThem()
        
        testRailPrint("Given I create reference \(secondReference) for note 2 and \(thirdReference) for note 3")
        cardView.typeInCardNoteByIndex(noteIndex: 1, text: secondReference)
        cardView.typeKeyboardKey(.enter)
        cardView.typeInCardNoteByIndex(noteIndex: 2, text: thirdReference)
        
        testRailPrint("Given I open \(cardName1)")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
        cardView.expandReferenceSection()
        
        /*testRailPrint("When I click Link first reference")
        TBD once link button is accessible
        
        testRailPrint("Then ")*/
                     
        testRailPrint("When I click Link All for remained references")
        cardView.expandReferenceSection()
            .linkAllReferences()
        
        testRailPrint("Then the card has no references available")
        XCTAssertTrue(waitHelper.waitForDoesntExist(cardView.getRefereceSectionCounterElement()))
    }
    
    func testReferencesSectionBreadcrumbs() throws {
        let cardView = createCardsAndReferenceThem()
        let additionalNote = "Level1"
        let editedValue = "Level0"

        testRailPrint("Then by default there is no breadcrumb available")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
            .expandReferenceSection()
        XCTAssertFalse(cardView.waitForBreadcrumbs(), "Breadcrumbs are available though shouldn't be")
        
        testRailPrint("When I create indentation level for the reference")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2)
            .typeKeyboardKey(.upArrow)
        cardView.app.typeText(additionalNote)
        cardView.typeKeyboardKey(.enter)
        cardView.typeKeyboardKey(.tab)
        
        testRailPrint("Then the breadcrumb appears in references section")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
            .expandReferenceSection()
        XCTAssertTrue(cardView.waitForBreadcrumbs(), "Breadcrumbs didn't load/appear")
        XCTAssertEqual(cardView.getBreadCrumbElementsNumber(), 1)
        XCTAssertEqual(cardView.getBreadCrumbTitleByIndex(0), additionalNote)
        
        testRailPrint("When I edit parent of indentation level")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2).getCardNoteElementByIndex(0).tapInTheMiddle()
        cardView.typeKeyboardKey(.delete, 1)
        cardView.app.typeText("0")
        
        testRailPrint("Then breadcrumb title is changed in accordance to previous changes")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
            .expandReferenceSection()
        XCTAssertTrue(cardView.waitForBreadcrumbs(), "Breadcrumbs didn't load/appear")
        XCTAssertEqual(cardView.getBreadCrumbElementsNumber(), 1)
        XCTAssertEqual(cardView.getBreadCrumbTitleByIndex(0), editedValue)
        
        testRailPrint("When delete indentation level")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName2).getCardNoteElementByIndex(1).tapInTheMiddle()
        shortcutsHelper.shortcutActionInvoke(action: .beginOfLine)
        cardView.typeKeyboardKey(.delete)
        cardView.typeKeyboardKey(.space)
        
        testRailPrint("Then there are no breadcrumbs in reference section")
        cardView.openCardFromRecentsList(cardTitleToOpen: cardName1)
            .expandReferenceSection()
        XCTAssertFalse(cardView.waitForBreadcrumbs(), "Breadcrumbs are available though shouldn't be")
    }
    
    func testReferencesIndentationLevels() throws {
        try XCTSkipIf(true, "WIP")
    }
}
