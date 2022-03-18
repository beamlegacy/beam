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
    var cardView = CardTestView()
    var noteForReference: String?
    
    func SKIPtestCreateBlockReference() throws {
        try XCTSkipIf(true, "Feature is temporary deprecated")
        let journalView = launchApp()

        step("Given I create I create a block reference"){
            noteForReference = createBlockRefForTwoCards(journalView, cardName1, cardName2)
        }

        step("Then it has correct number and content"){
            XCTAssertEqual(cardView.getNumberOfBlockRefs(), 1)
            XCTAssertEqual(cardView.getElementStringValue(element:  cardView.getBlockRefByIndex(0)), noteForReference!)
        }

    }
    
    func SKIPtestLockUnlockBlockReference() throws {
        try XCTSkipIf(true, "Feature is temporary deprecated")
        let journalView = launchApp()
        let textToAdd = " additional text"
        step("Given I create I create a block reference"){
            noteForReference = createBlockRefForTwoCards(journalView, cardName1, cardName2)
        }
        
        let blockRef = cardView.getBlockRefByIndex(0)
        step("Then the block reference is locked by default"){
            blockRef.tapInTheMiddle()
            blockRef.doubleClick() //Double click is just for sure the field is not editable
            XCTAssertTrue(WaitHelper().waitForKeyboardUnfocus(blockRef))
        }

        step("When I unlock the block reference"){
            cardView.blockReferenceMenuActionTrigger(.blockRefUnlock, blockRefNumber: 1)
        }
        
        step("Then it can be changed"){
            blockRef.tapInTheMiddle()
            XCTAssertTrue(WaitHelper().waitForKeyboardFocus(blockRef))
            blockRef.typeText("\(textToAdd)\r")
            XCTAssertEqual(cardView.getElementStringValue(element: blockRef), noteForReference! + textToAdd)
            cardView.typeKeyboardKey(.delete, textToAdd.count)
            XCTAssertEqual(cardView.getElementStringValue(element: blockRef), noteForReference!)
        }
    }
    
    func SKIPtestViewBlockReferenceOrigin() throws {
        try XCTSkipIf(true, "Feature is temporary deprecated")
        let journalView = launchApp()
        
        step("Given I create 2 notes"){
            createBlockRefForTwoCards(journalView, cardName1, cardName2)
        }

        step("Then I can see correct origin of the reference"){
            cardView.blockReferenceMenuActionTrigger(.blockRefOrigin, blockRefNumber: 1)
            XCTAssertTrue(WaitHelper().waitForStringValueEqual(cardName1, cardView.cardTitle), "Actual note name is \(cardView.cardTitle)")
        }

    }
    
    func SKIPtestRemoveBlockReference() throws {
        try XCTSkipIf(true, "Feature is temporary deprecated")
        let journalView = launchApp()
        
        step("Given I create 2 notes"){
            noteForReference = createBlockRefForTwoCards(journalView, cardName1, cardName2)
        }

        step("Then I can successfully remove it"){
            cardView.blockReferenceMenuActionTrigger(.blockRefRemove, blockRefNumber: 1)
            XCTAssertTrue(WaitHelper().waitForDoesntExist( cardView.textView(CardViewLocators.TextViews.blockReference.accessibilityIdentifier)))
        }

        step("Then removing block reference doesn't remove the source text"){
            journalView.openRecentCardByName(cardName2)
            let currentSourceNote = cardView.getElementStringValue(element:  cardView.getCardNotesForVisiblePart()[1])
            XCTAssertEqual(currentSourceNote, noteForReference!)
        }

    }
    
    @discardableResult
    func createBlockRefForTwoCards(_ view: JournalTestView, _ cardName1: String, _ cardName2: String) -> String {
        view.createCardViaOmniboxSearch(cardName1)
        view.createCardViaOmniboxSearch(cardName2)
        let helper = BeamUITestsHelper(view.app)
        helper.tapCommand(.insertTextInCurrentNote)
        
        let noteForReference = cardView.getElementStringValue(element:cardView.getCardNotesForVisiblePart()[1])
        let referencePart = (noteForReference.substring(from: 0, to: 6))
        
        view.openRecentCardByName(cardName1)
        cardView.addTestRef(referencePart)
        return noteForReference
    }
}
