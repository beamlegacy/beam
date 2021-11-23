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
    
    func testCreateCardLink()  {
        let journalView = launchApp()
       
        testRailPrint("Given I create 2 cards")
        journalView.createCardViaOmnibarSearch(cardName1)
        let cardView = journalView.createCardViaOmnibarSearch(cardName2)
        
        testRailPrint("Then I link card 2 to card 1")
        cardView.createBiDiLink(cardName1).openBiDiLink(0)
        XCTAssertEqual(cardView.getLinksNamesNumber(), 1)
        XCTAssertEqual(cardView.getLinksContentNumber(), 1)
        XCTAssertEqual(cardView.getLinkNameByIndex(0), cardName2)
        XCTAssertEqual(cardView.getLinkContentByIndex(0), cardName1 + " ") //looks like a bug

        testRailPrint("Then I can navigate to a card by Link both sides")
        cardView.openLinkByIndex(0)
        XCTAssertEqual(cardView.getLinksNamesNumber(), 0)
        cardView.openBiDiLink(0)
        XCTAssertEqual(cardView.getLinksNamesNumber(), 1)
        XCTAssertEqual(cardView.getLinkContentByIndex(0), cardName1 + " ")
    }
}
