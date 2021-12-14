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
    
    func testCreateCardReference() {
        let journalView = launchApp()
        
        testRailPrint("Given I create 2 cards")
        journalView.createCardViaOmnibarSearch(cardName1)
        let cardView = journalView.createCardViaOmnibarSearch(cardName2)
        
        testRailPrint("Then I reference card 2 to card 1")
        cardView.createReference(cardName1)
        journalView.openRecentCardByName(cardName1)
        XCTAssertEqual(cardView.getLinksNamesNumber(), 0) //Link ONLY
        XCTAssertEqual(cardView.getLinksContentNumber(), 0)
        
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
}
