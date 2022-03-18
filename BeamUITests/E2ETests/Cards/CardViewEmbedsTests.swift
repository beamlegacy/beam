//
//  CardViewEmbedsTests.swift
//  BeamUITests
//
//  Created by Andrii on 26/11/2021.
//

import Foundation
import XCTest

class CardViewEmbedsTests: BaseTest {
    
    var cardView: CardTestView?
    
    func testEmbedsCollapseExpandIcons() throws {
        let toLinkTitle = "to Link"
        let toImageTitle = "to Image"
        let pnsView = PnSTestView()
        let webView = WebTestView()
        var expandButton: XCUIElement?
        
        step("When I add image to a note"){
            BeamUITestsHelper(launchApp().app).openTestPage(page: .page4)
            let imageItemToAdd = pnsView.image("forest")
            pnsView.addToTodayCard(imageItemToAdd)
        }
        
        step("Then I see collapse button"){
            cardView = webView.openDestinationCard()
            expandButton = cardView!.getNoteExpandButtonByIndex(noteIndex: 0)
            XCTAssertEqual(cardView!.getNotesExpandButtonsCount(), 1)
            XCTAssertEqual(expandButton!.title, toLinkTitle)
            XCTAssertFalse(cardView!.isImageNodeCollapsed(nodeIndex: 0))
        }
        
        let sizeBeforeCollapse = cardView!.getImageNodeByIndex(nodeIndex: 0).getSize()
        step("When I click collapse button"){
            cardView!.clickNoteExpandButtonByIndex(noteIndex: 0)
        }
        
        let sizeAfterCollapse = cardView!.getImageNodeByIndex(nodeIndex: 0).getSize()
        step("Then image node is collapsed"){
            XCTAssertEqual(expandButton!.title, toImageTitle)
            XCTAssertTrue(cardView!.isImageNodeCollapsed(nodeIndex: 0))
            XCTAssertTrue(cardView!.getImageNodeCollapsedTitle(nodeIndex: 0).hasSuffix("/Build/Products/Variant-NoSanitizers/Test/Beam.app/Contents/Resources/UITests-4.html "))
        }
        
        step("Then element width and height is changed accordingly"){
            //XCTAssertEqual(sizeBeforeCollapse.width, sizeAfterCollapse.width) too flaky due to issue with random resizing of notes
            XCTAssertGreaterThan(sizeBeforeCollapse.height, sizeAfterCollapse.height * 2)
            XCTAssertLessThan(sizeBeforeCollapse.height, sizeAfterCollapse.height * 4.5)
        }
        
        step("Then image node is expanded"){
            cardView!.clickNoteExpandButtonByIndex(noteIndex: 0)
            XCTAssertEqual(cardView!.getNotesExpandButtonsCount(), 1)
            XCTAssertEqual(cardView!.getNoteExpandButtonByIndex(noteIndex: 0).title, toLinkTitle)
            XCTAssertFalse(cardView!.isImageNodeCollapsed(nodeIndex: 0))
        }
        
        step("Then element width and height is changed accordingly"){
            let sizeAfterExpand = cardView!.getImageNodeByIndex(nodeIndex: 0).getSize()
            // XCTAssertEqual(sizeBeforeCollapse.width, sizeAfterExpand.width) too flaky due to issue with random resizing of notes
            XCTAssertEqual(sizeBeforeCollapse.height, sizeAfterExpand.height)
        }
       
    }

    func testEmbedVideoMediaControlOld() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        helper.tapCommand(.disableCreateJournalOnce)
        _testEmbedVideoMediaControl(expectedWebViewCount: 1)
    }

    func testEmbedVideoMediaControlNew() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        helper.tapCommand(.enableCreateJournalOnce)
        _testEmbedVideoMediaControl(expectedWebViewCount: 1)
        helper.tapCommand(.disableCreateJournalOnce)
    }

    func _testEmbedVideoMediaControl(expectedWebViewCount: Int) {
        
        let journalView = launchApp()
        var webView: WebTestView?
        
        step("Given open today's card"){
            cardView = journalView
                .openAllCardsMenu()
                .openFirstCard()
        }

        step("When I type a video url"){
            cardView!.typeInCardNoteByIndex(noteIndex: 0, text: "https://www.youtube.com/watch?v=WlneLrftoOM ")
        }

        step("And right click on it to show as embed"){
            let textNode = cardView!.getTextNodeByIndex(nodeIndex: 0)
            textNode.rightClick()
            ContextMenuTestView(key: NoteViewLocators.Groups.contextMenu.accessibilityIdentifier).clickItem(item: .asEmbed)
        }
        
        let youtubeButtons = cardView!.app.webViews.buttons
        step("Then the video loads"){
            XCTAssertTrue(youtubeButtons.firstMatch.waitForExistence(timeout: implicitWaitTimeout), "Embed video couldn't load")
        }
       
        let embedNode = cardView!.getEmbedNodeByIndex(nodeIndex: 0)
        step("When I start the video"){
            embedNode.tapInTheMiddle()
            webView = WebTestView()
            XCTAssertEqual(webView!.getNumberOfWebViewInMemory(), expectedWebViewCount)
        }
        
        let mediaPlayingButton = cardView!.image(CardViewLocators.Buttons.noteMediaPlaying.accessibilityIdentifier)
        let mediaMutedButton = cardView!.image(CardViewLocators.Buttons.noteMediaMuted.accessibilityIdentifier)
        step("Then the note media mute button is shown"){
            XCTAssertTrue(mediaPlayingButton.waitForExistence(timeout: implicitWaitTimeout))
            embedNode.hoverInTheMiddle()
        }
        
        let youtubePlayPauseButton = youtubeButtons.matching(NSPredicate(format: "label CONTAINS '(k)'")).firstMatch
        step("And the note media play button is shown"){
            XCTAssertTrue(youtubePlayPauseButton.exists)
        }
       
        let allCardsView = journalView.openAllCardsMenu()
        step("When I leave note and come back"){
            XCTAssertTrue(mediaPlayingButton.exists)
            XCTAssertFalse(youtubePlayPauseButton.exists)
            allCardsView.openFirstCard()
        }
       
        step("Then the video is still playing"){
            embedNode.hoverInTheMiddle()
            XCTAssertTrue(youtubePlayPauseButton.exists)
            XCTAssertEqual(webView!.getNumberOfWebViewInMemory(), expectedWebViewCount)
        }
       
        step("When I pause the video"){
            embedNode.tapInTheMiddle()
            XCTAssertTrue(youtubePlayPauseButton.exists)
        }
       
        step("Then media button disappear"){
            XCTAssertFalse(mediaPlayingButton.exists)
            XCTAssertFalse(mediaMutedButton.exists)
        }

        step("When I resume the video"){
            youtubePlayPauseButton.tap()
        }
        
        step("Then media button comes back"){
            XCTAssertTrue(mediaPlayingButton.waitForExistence(timeout: implicitWaitTimeout))
        }

        step("When I delete the embed node"){
            embedNode.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).tap()
            cardView!.typeKeyboardKey(.delete, 1)
        }
       
        step("Then no more webview is playing"){
            XCTAssertFalse(mediaPlayingButton.exists)
            XCTAssertFalse(mediaMutedButton.exists)
            XCTAssertEqual(webView!.getNumberOfWebViewInMemory(), 0)
        }
      
    }
}
