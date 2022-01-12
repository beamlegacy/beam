//
//  BlockReference.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation
import XCTest

class BlockReferenceTests: BaseTest {
    
    let cardName1 = "Block 1"
    let cardName2 = "Block 2"
    
    func testCreateBlockReference() throws {
        try XCTSkipIf(true, "Feature is temporary deprecated")
        let journalView = launchApp()
        
        testRailPrint("Given I create I create a block reference")
        let noteForReference = createBlockRefForTwoCards(journalView, cardName1, cardName2)
        let cardView = CardTestView()
        
        testRailPrint("Then it has correct number and content")
        XCTAssertEqual(cardView.getNumberOfBlockRefs(), 1)
        XCTAssertEqual(cardView.getBlockRefByIndex(0).value as? String, noteForReference)
    }
    
    func testLockUnlockBlockReference() throws {
        try XCTSkipIf(true, "Feature is temporary deprecated")
        let journalView = launchApp()
        let textToAdd = " additional text"
        testRailPrint("Given I create I create a block reference")
        let noteForReference = createBlockRefForTwoCards(journalView, cardName1, cardName2)
        let cardView = CardTestView()
        
        testRailPrint("Then the block reference is locked by default")
        let blockRef = cardView.getBlockRefByIndex(0)
        blockRef.tapInTheMiddle()
        blockRef.doubleClick() //Double click is just for sure the field is not editable
        XCTAssertTrue(WaitHelper().waitForKeyboardUnfocus(blockRef))
        
        testRailPrint("When I unlock the block reference")
        cardView.blockReferenceMenuActionTrigger(.blockRefUnlock, blockRefNumber: 1)
        testRailPrint("Then it can be changed")
        blockRef.tapInTheMiddle()
        XCTAssertTrue(WaitHelper().waitForKeyboardFocus(blockRef))
        blockRef.typeText("\(textToAdd)\r")
        XCTAssertEqual(blockRef.value as? String, noteForReference + textToAdd)
        cardView.typeKeyboardKey(.delete, textToAdd.count)
        XCTAssertEqual(blockRef.value as? String, noteForReference)
    }
    
    func testViewBlockReferenceOrigin() throws {
        try XCTSkipIf(true, "Feature is temporary deprecated")
        let journalView = launchApp()
        
        testRailPrint("Given I create 2 notes")
        createBlockRefForTwoCards(journalView, cardName1, cardName2)
        let cardView = CardTestView()
        
        testRailPrint("Then I can see correct origin of the reference")
        cardView.blockReferenceMenuActionTrigger(.blockRefOrigin, blockRefNumber: 1)
        XCTAssertTrue(WaitHelper().waitForStringValueEqual(cardName1, cardView.cardTitle), "Actual note name is \(cardView.cardTitle)")
    }
    
    func testRemoveBlockReference() throws {
        try XCTSkipIf(true, "Feature is temporary deprecated")
        let journalView = launchApp()
        
        testRailPrint("Given I create 2 notes")
        let noteForReference = createBlockRefForTwoCards(journalView, cardName1, cardName2)
        let cardView = CardTestView()
        
        testRailPrint("Then I can successfully remove it")
        cardView.blockReferenceMenuActionTrigger(.blockRefRemove, blockRefNumber: 1)
        
        XCTAssertTrue(WaitHelper().waitForDoesntExist( cardView.textView(CardViewLocators.TextViews.blockReference.accessibilityIdentifier)))
        
        testRailPrint("Then removing block reference doesn't remove the source text")
        journalView.openRecentCardByName(cardName2)
        let currentSourceNote = (cardView.getCardNotesForVisiblePart()[1].value as? String)!
        XCTAssertEqual(currentSourceNote, noteForReference)
    }
    
    @discardableResult
    func createBlockRefForTwoCards(_ view: JournalTestView, _ cardName1: String, _ cardName2: String) -> String {
        view.createCardViaOmniboxSearch(cardName1)
        view.createCardViaOmniboxSearch(cardName2)
        let helper = BeamUITestsHelper(view.app)
        helper.tapCommand(.insertTextInCurrentNote)
        
        let cardView = CardTestView()
        let noteForReference = (cardView.getCardNotesForVisiblePart()[1].value as? String)!
        let referencePart = (noteForReference.substring(from: 0, to: 6))
        
        view.openRecentCardByName(cardName1)
        cardView.addTestRef(referencePart)
        return noteForReference
    }
}
