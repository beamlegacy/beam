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
        
        testRailPrint("When I add image to a note")
        BeamUITestsHelper(launchApp().app).openTestPage(page: .page4)
        let imageItemToAdd = pnsView.image("forest")
        pnsView.addToTodayCard(imageItemToAdd)
        
        testRailPrint("Then I see collapse button")
        let cardView = webView.openDestinationCard()
        let expandButton = cardView.getNoteExpandButtonByIndex(noteIndex: 0)
        XCTAssertEqual(cardView.getNotesExpandButtonsCount(), 1)
        XCTAssertEqual(expandButton.title, toLinkTitle)
        XCTAssertFalse(cardView.isImageNodeCollapsed(nodeIndex: 0))
        
        testRailPrint("When I click collapse button")
        let sizeBeforeCollapse = cardView.getImageNodeByIndex(nodeIndex: 0).getSize()
        cardView.clickNoteExpandButtonByIndex(noteIndex: 0)
        
        testRailPrint("Then image node is collapsed")
        XCTAssertEqual(expandButton.title, toImageTitle)
        XCTAssertTrue(cardView.isImageNodeCollapsed(nodeIndex: 0))
        XCTAssertTrue(cardView.getImageNodeCollapsedTitle(nodeIndex: 0).hasSuffix("/Build/Products/Variant-NoSanitizers/Test/Beam.app/Contents/Resources/UITests-4.html "))
        let sizeAfterCollapse = cardView.getImageNodeByIndex(nodeIndex: 0).getSize()
        
        testRailPrint("Then element width and height is changed accordingly")
        //XCTAssertEqual(sizeBeforeCollapse.width, sizeAfterCollapse.width) too flaky due to issue with random resizing of notes
        XCTAssertGreaterThan(sizeBeforeCollapse.height, sizeAfterCollapse.height * 2)
        XCTAssertLessThan(sizeBeforeCollapse.height, sizeAfterCollapse.height * 4.5)
        
        testRailPrint("Then image node is expanded")
        cardView.clickNoteExpandButtonByIndex(noteIndex: 0)
        XCTAssertEqual(cardView.getNotesExpandButtonsCount(), 1)
        XCTAssertEqual(cardView.getNoteExpandButtonByIndex(noteIndex: 0).title, toLinkTitle)
        XCTAssertFalse(cardView.isImageNodeCollapsed(nodeIndex: 0))
        
        testRailPrint("Then element width and height is changed accordingly")
        let sizeAfterExpand = cardView.getImageNodeByIndex(nodeIndex: 0).getSize()
        // XCTAssertEqual(sizeBeforeCollapse.width, sizeAfterExpand.width) too flaky due to issue with random resizing of notes
        XCTAssertEqual(sizeBeforeCollapse.height, sizeAfterExpand.height)
    }

    func testEmbedVideoMediaControl() {
        testRailPrint("Given open today's card")
        let journalView = launchApp()
        let cardView = journalView
            .openAllCardsMenu()
            .openFirstCard()

        testRailPrint("When I type a video url")
        cardView.typeInCardNoteByIndex(noteIndex: 0, text: "https://www.youtube.com/watch?v=WlneLrftoOM ")
        let textNode = cardView.getTextNodeByIndex(nodeIndex: 0)
        testRailPrint("And right click on it to show as embed")
        textNode.rightClick()
        ContextMenuTestView(key: NoteViewLocators.Groups.contextMenu.accessibilityIdentifier).clickItem(item: .asEmbed)

        testRailPrint("Then the video loads")
        let youtubeButtons = cardView.app.webViews.buttons
        XCTAssertTrue(youtubeButtons.firstMatch.waitForExistence(timeout: implicitWaitTimeout), "Embed video couldn't load")

        testRailPrint("When I start the video")
        let embedNode = cardView.getEmbedNodeByIndex(nodeIndex: 0)
        embedNode.tapInTheMiddle()
        let webView = WebTestView()
        XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 1)

        testRailPrint("Then the note media mute button is shown")
        let mediaPlayingButton = cardView.image(CardViewLocators.Buttons.noteMediaPlaying.accessibilityIdentifier)
        let mediaMutedButton = cardView.image(CardViewLocators.Buttons.noteMediaMuted.accessibilityIdentifier)
        XCTAssertTrue(mediaPlayingButton.waitForExistence(timeout: implicitWaitTimeout))
        embedNode.hoverInTheMiddle()
        let youtubePlayPauseButton = youtubeButtons.matching(NSPredicate(format: "label CONTAINS '(k)'")).firstMatch
        XCTAssertTrue(youtubePlayPauseButton.exists)

        testRailPrint("When I leave note and come back")
        let allCardsView = journalView.openAllCardsMenu()
        XCTAssertTrue(mediaPlayingButton.exists)
        XCTAssertFalse(youtubePlayPauseButton.exists)
        allCardsView.openFirstCard()
        testRailPrint("Then the video is still playing")
        embedNode.hoverInTheMiddle()
        XCTAssertTrue(youtubePlayPauseButton.exists)
        XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 1)

        testRailPrint("When I pause the video")
        embedNode.tapInTheMiddle()
        XCTAssertTrue(youtubePlayPauseButton.exists)
        testRailPrint("Then media button disappear")
        XCTAssertFalse(mediaPlayingButton.exists)
        XCTAssertFalse(mediaMutedButton.exists)

        testRailPrint("When I resume the video")
        youtubePlayPauseButton.tap()
        testRailPrint("Then media button comes back")
        XCTAssertTrue(mediaPlayingButton.waitForExistence(timeout: implicitWaitTimeout))

        testRailPrint("When I delete the embed node")
        embedNode.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).tap()
        cardView.typeKeyboardKey(.delete, 1)
        testRailPrint("Then no more webview is playing")
        XCTAssertFalse(mediaPlayingButton.exists)
        XCTAssertFalse(mediaMutedButton.exists)
        XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 0)
    }
}
