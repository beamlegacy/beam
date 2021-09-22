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
    let todayCardNameCreationViewFormat = DateHelper().getTodaysDateString(DateHelper.DateFormats.cardViewCreation.rawValue)
    let todayCardNameTitleViewFormat = DateHelper().getTodaysDateString(DateHelper.DateFormats.cardViewTitle.rawValue)
    
    func testCreateCardLink()  {
        let journalView = launchApp()
       
        testRailPrint("Given I create 2 cards")
        journalView.createCardViaOmnibarSearch(cardName1)
        let cardView = journalView.createCardViaOmnibarSearch(cardName2)
        
        testRailPrint("Then I link card 2 to card 1")
        cardView.createBiDiLink(cardName1).openBiDiLink(0)
        XCTAssertEqual(cardView.getLinksNamesNumber(), 2)
        XCTAssertEqual(cardView.getLinksContentNumber(), 2)
        XCTAssertEqual(cardView.getLinkNameByIndex(0), cardName2)
        XCTAssertEqual(cardView.getLinkContentByIndex(0), cardName1 + " ") //looks like a bug
        XCTAssertTrue(cardView.getLinkNameByIndex(1) == todayCardNameCreationViewFormat || cardView.getLinkNameByIndex(1) == todayCardNameTitleViewFormat, "Actual link name is \(String(describing: cardView.getLinkNameByIndex(1)))")
        XCTAssertEqual(cardView.getLinkContentByIndex(1), cardName1)
        
        testRailPrint("Then I can navigate to a card by Link both sides")
        cardView.openLinkByIndex(0)
        XCTAssertEqual(cardView.getLinksNamesNumber(), 1)
        XCTAssertEqual(cardView.getLinkContentByIndex(0), cardName2)
        cardView.openBiDiLink(0)
        XCTAssertEqual(cardView.getLinksNamesNumber(), 2)
        XCTAssertEqual(cardView.getLinkContentByIndex(0), cardName1 + " ")
    }
    
    override func tearDown() {
        UITestsMenuBar().destroyDB()
    }
    
}
