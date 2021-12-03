//
//  CardViewEmbedsTests.swift
//  BeamUITests
//
//  Created by Andrii on 26/11/2021.
//

import Foundation
import XCTest

class CardViewEmbedsTests: BaseTest {
    
    func testEmbedsCollapseExpandIcons() {
        let toLinkTitle = "to Link"
        let toImageTitle = "to Image"
        let pnsView = PnSTestView()
        let webView = WebTestView()
        
        testRailPrint("When I add image to a card")
        BeamUITestsHelper(launchApp().app).openTestPage(page: .page4)
        let imageItemToAdd = pnsView.image("forest")
        pnsView.addToTodayCard(imageItemToAdd)
        
        testRailPrint("Then I see collapse button")
        let cardView = webView.openDestinationCard()
        let expandButton = cardView.getNoteExpandButtonByIndex(noteIndex: 0)
        XCTAssertEqual(cardView.getNotesExpandButtonsCount(), 1)
        XCTAssertEqual(expandButton.title, toLinkTitle)
        
        testRailPrint("When I click collapse button")
        let sizeBeforeCollapse = cardView.getImageNoteByIndex(noteIndex: 0).getSize()
        cardView.clickNoteExpandButtonByIndex(noteIndex: 0)
        
        testRailPrint("Then image node is collapsed")
        XCTAssertEqual(expandButton.title, toImageTitle)
        let sizeAfterCollapse = cardView.getImageNoteByIndex(noteIndex: 0).getSize()
        
        testRailPrint("Then element width and height is changed accordingly")
        XCTAssertEqual(sizeBeforeCollapse.width, sizeAfterCollapse.width)
        XCTAssertTrue(sizeBeforeCollapse.height > sizeAfterCollapse.height * 2 && sizeBeforeCollapse.height < sizeAfterCollapse.height * 4)
        
        testRailPrint("Then image node is expanded")
        cardView.clickNoteExpandButtonByIndex(noteIndex: 0)
        XCTAssertEqual(cardView.getNotesExpandButtonsCount(), 1)
        XCTAssertEqual(cardView.getNoteExpandButtonByIndex(noteIndex: 0).title, toLinkTitle)
        
        testRailPrint("Then element width and height is changed accordingly")
        let sizeAfterExpand = cardView.getImageNoteByIndex(noteIndex: 0).getSize()
        XCTAssertEqual(sizeBeforeCollapse.width, sizeAfterExpand.width)
        XCTAssertEqual(sizeBeforeCollapse.height, sizeAfterExpand.height)
    }
    
}
