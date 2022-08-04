//
//  NoteViewEmbedsTests.swift
//  BeamUITests
//
//  Created by Andrii on 26/11/2021.
//

import Foundation
import XCTest

class NoteViewEmbedsTests: BaseTest {
    
    var noteView: NoteTestView?
    
    func testEmbedsCollapseExpandIcons() throws {
        let toLinkTitle = "to Link"
        let toImageTitle = "to Image"
        let pnsView = PnSTestView()
        var expandButton: XCUIElement?
        
        step("When I add image to a note"){
            launchApp()
            uiMenu.loadUITestPage4()
            let imageItemToAdd = pnsView.image("forest")
            pnsView.addToTodayNote(imageItemToAdd)
        }
        
        step("Then I see collapse button"){
            noteView = webView.openDestinationNote()
            expandButton = noteView!.getNoteExpandButtonByIndex(noteIndex: 0)
            XCTAssertEqual(noteView!.getNotesExpandButtonsCount(), 1)
            XCTAssertEqual(expandButton!.title, toLinkTitle)
            XCTAssertFalse(noteView!.isImageNodeCollapsed(nodeIndex: 0))
        }
        
        let sizeBeforeCollapse = noteView!.getImageNodeByIndex(nodeIndex: 0).getSize()
        step("When I click collapse button"){
            noteView!.clickNoteExpandButtonByIndex(noteIndex: 0)
        }
        
        let sizeAfterCollapse = noteView!.getImageNodeByIndex(nodeIndex: 0).getSize()
        step("Then image node is collapsed"){
            XCTAssertEqual(expandButton!.title, toImageTitle)
            XCTAssertTrue(noteView!.isImageNodeCollapsed(nodeIndex: 0))
            XCTAssertTrue(noteView!.getImageNodeCollapsedTitle(nodeIndex: 0).hasSuffix("/Build/Products/Variant-NoSanitizers/Test/Beam.app/Contents/Resources/UITests-4.html\u{fffc}"))
        }
        
        step("Then element width and height is changed accordingly"){
            //XCTAssertEqual(sizeBeforeCollapse.width, sizeAfterCollapse.width) too flaky due to issue with random resizing of notes
            XCTAssertGreaterThan(sizeBeforeCollapse.height, sizeAfterCollapse.height * 2)
            XCTAssertLessThan(sizeBeforeCollapse.height, sizeAfterCollapse.height * 4.5)
        }
        
        step("Then image node is expanded"){
            noteView!.clickNoteExpandButtonByIndex(noteIndex: 0)
            XCTAssertEqual(noteView!.getNotesExpandButtonsCount(), 1)
            XCTAssertEqual(noteView!.getNoteExpandButtonByIndex(noteIndex: 0).title, toLinkTitle)
            XCTAssertFalse(noteView!.isImageNodeCollapsed(nodeIndex: 0))
        }
        
        step("Then element width and height is changed accordingly"){
            let sizeAfterExpand = noteView!.getImageNodeByIndex(nodeIndex: 0).getSize()
            // XCTAssertEqual(sizeBeforeCollapse.width, sizeAfterExpand.width) too flaky due to issue with random resizing of notes
            XCTAssertEqual(sizeBeforeCollapse.height, sizeAfterExpand.height)
        }
       
    }

    func testEmbedVideoMediaControlOld() {
        launchApp()
        uiMenu.disableCreateJournalOnce()
        _testEmbedVideoMediaControl(expectedWebViewCount: 1)
    }

    func testEmbedVideoMediaControlNew() {
        launchApp()
        uiMenu.enableCreateJournalOnce()
        _testEmbedVideoMediaControl(expectedWebViewCount: 1)
        uiMenu.disableCreateJournalOnce()
    }

    func _testEmbedVideoMediaControl(expectedWebViewCount: Int) {
        
        let journalView = launchApp()
        
        step("Given open today's note"){
            noteView = journalView
                .openAllNotesMenu()
                .openFirstNote()
        }

        step("When I type a video url"){
            noteView!.typeInNoteNodeByIndex(noteIndex: 0, text: "https://www.youtube.com/watch?v=WlneLrftoOM ")
        }

        step("And right click on it to show as embed"){
            let textNode = noteView!.getTextNodeByIndex(nodeIndex: 0)
            textNode.rightClick()
            NoteTestView().menuItem(NoteViewLocators.RightClickMenuItems.showAsEmbed.accessibilityIdentifier).tapInTheMiddle()
        }
        
        let youtubeButtons = noteView!.app.webViews.buttons
        step("Then the video loads"){
            XCTAssertTrue(youtubeButtons.firstMatch.waitForExistence(timeout: BaseTest.implicitWaitTimeout), "Embed video couldn't load")
        }
       
        let embedNode = noteView!.getEmbedNodeByIndex(nodeIndex: 0)
        step("When I start the video"){
            embedNode.tapInTheMiddle()
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), expectedWebViewCount)
        }
        
        let mediaPlayingButton = noteView!.image(NoteViewLocators.Buttons.noteMediaPlaying.accessibilityIdentifier)
        let mediaMutedButton = noteView!.image(NoteViewLocators.Buttons.noteMediaMuted.accessibilityIdentifier)
        step("Then the note media mute button is shown"){
            XCTAssertTrue(mediaPlayingButton.waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            embedNode.hoverInTheMiddle()
        }
        
        let youtubePlayPauseButton = youtubeButtons.matching(NSPredicate(format: "label CONTAINS '(k)'")).firstMatch
        step("And the note media play button is shown"){
            XCTAssertTrue(youtubePlayPauseButton.exists)
        }
       
        let allNotesView = journalView.openAllNotesMenu()
        step("When I leave note and come back"){
            XCTAssertTrue(mediaPlayingButton.exists)
            XCTAssertFalse(youtubePlayPauseButton.exists)
            allNotesView.openFirstNote()
        }
       
        step("Then the video is still playing"){
            embedNode.hoverInTheMiddle()
            XCTAssertTrue(youtubePlayPauseButton.exists)
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), expectedWebViewCount)
        }
       
        step("When I pause the video"){
            embedNode.tapInTheMiddle()
            XCTAssertTrue(youtubePlayPauseButton.exists)
        }
       
        step("Then media button disappear"){
            // Because we keep the webview alive when paused, we should still display the playing button
            XCTAssertTrue(mediaPlayingButton.exists)
            XCTAssertFalse(mediaMutedButton.exists)
        }

        step("When I resume the video"){
            youtubePlayPauseButton.tap()
        }
        
        step("Then media button comes back"){
            XCTAssertTrue(mediaPlayingButton.waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

        step("When I delete the embed node"){
            embedNode.coordinate(withNormalizedOffset: .init(dx: 1.05, dy: 0.5)).tap()
            noteView!.typeKeyboardKey(.delete, 1)
        }
       
        step("Then no more webview is playing"){
            XCTAssertFalse(mediaPlayingButton.exists)
            XCTAssertFalse(mediaMutedButton.exists)
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 0)
        }
      
    }
}
