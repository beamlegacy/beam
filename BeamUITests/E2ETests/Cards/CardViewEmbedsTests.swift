//
//  CardViewEmbedsTests.swift
//  BeamUITests
//
//  Created by Andrii on 26/11/2021.
//

import Foundation
import XCTest

class CardViewEmbedsTests: BaseTest {
    
    func testEmbedsCollapseExpandIcons() throws {
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
        XCTAssertFalse(cardView.isImageNoteCollapsed(noteIndex: 0))
        
        testRailPrint("When I click collapse button")
        let sizeBeforeCollapse = cardView.getImageNoteByIndex(noteIndex: 0).getSize()
        cardView.clickNoteExpandButtonByIndex(noteIndex: 0)
        
        testRailPrint("Then image node is collapsed")
        XCTAssertEqual(expandButton.title, toImageTitle)
        XCTAssertTrue(cardView.isImageNoteCollapsed(noteIndex: 0))
        XCTAssertTrue(cardView.getImageNoteCollapsedTitle(noteIndex: 0).hasSuffix("/Build/Products/Variant-NoSanitizers/Test/Beam.app/Contents/Resources/UITests-4.html "))
        let sizeAfterCollapse = cardView.getImageNoteByIndex(noteIndex: 0).getSize()
        
        testRailPrint("Then element width and height is changed accordingly")
        //XCTAssertEqual(sizeBeforeCollapse.width, sizeAfterCollapse.width) too flaky due to issue with random resizing of notes
        XCTAssertGreaterThan(sizeBeforeCollapse.height, sizeAfterCollapse.height * 2)
        XCTAssertLessThan(sizeBeforeCollapse.height, sizeAfterCollapse.height * 4.5)
        
        testRailPrint("Then image node is expanded")
        cardView.clickNoteExpandButtonByIndex(noteIndex: 0)
        XCTAssertEqual(cardView.getNotesExpandButtonsCount(), 1)
        XCTAssertEqual(cardView.getNoteExpandButtonByIndex(noteIndex: 0).title, toLinkTitle)
        XCTAssertFalse(cardView.isImageNoteCollapsed(noteIndex: 0))
        
        testRailPrint("Then element width and height is changed accordingly")
        let sizeAfterExpand = cardView.getImageNoteByIndex(noteIndex: 0).getSize()
        // XCTAssertEqual(sizeBeforeCollapse.width, sizeAfterExpand.width) too flaky due to issue with random resizing of notes
        XCTAssertEqual(sizeBeforeCollapse.height, sizeAfterExpand.height)
    }
    
}
