//
//  PnSAddToNoteTests.swift
//  BeamUITests
//
//  Created by Andrii on 17.09.2021.
//

import Foundation
import XCTest

class PnSAddToNoteTests: BaseTest {
       
    let noteNameToBeCreated = "Test1"
    let pnsView = PnSTestView()
    let titles = [
        "Point And Shoot Test Fixture Ultralight Beam",
        "Point And Shoot Test Fixture I-Beam",
        "Point And Shoot Test Fixture Cursor"
    ]
    var noteNodes: [XCUIElement]!
    var noteView: NoteTestView!
    var journalView: JournalTestView!

    override func setUp() {
        journalView = launchApp()
        uiMenu.resizeSquare1000()
    }
    
    func SKIPtestAddTextToTodaysNote() throws {
        try XCTSkipIf(true, "Skipped so far, to replace NavigationCollectUITests")
        let expectedItemText1 = "Point And Shoot Test Fixture Cursor"
        let expectedItemText2 = "Go to UITests-1"
        var todaysDateInNoteTitleFormat: String?
        
        step("Given I open Test page"){
            uiMenu.loadUITestPage3()
        }
        
        step("When I point and shoot the following text and add it to Todays note"){
            let prefix = "Go to "
            let linkText = "UITests-1"
            let parent = pnsView.app.webViews.containing(.staticText, identifier: linkText).element
            let textElement = parent.staticTexts[prefix].firstMatch
            pnsView.addToTodayNote(textElement)
            todaysDateInNoteTitleFormat = DateHelper().getTodaysDateString(.noteViewTitle)
        }
        
        step("Then it is successfully added to the note"){
            XCTAssertTrue(pnsView.assertAddedToNoteSuccessfully(todaysDateInNoteTitleFormat!))
            OmniBoxTestView().navigateToNoteViaPivotButton()
            journalView.waitForJournalViewToLoad()
            noteNodes = NoteTestView().getNoteNodesForVisiblePart()
        }
        
        step("Then \(expectedItemText1) and \(expectedItemText2) items are displayed in the note"){
            XCTAssertEqual(noteNodes.count, 2)
            XCTAssertEqual(noteNodes[0].getStringValue(), expectedItemText1)
            XCTAssertEqual(noteNodes[1].getStringValue(), expectedItemText2)
        }

    }
    
    func testAddTextToNewNote() {
        
        step("Given I open Test page"){
            uiMenu.loadUITestPage3()
            let textElementToAdd = pnsView.staticText(" capital letter \"I\". The purpose of this cursor is to indicate that the text beneath the cursor can be highlighted, and sometime")
            pnsView.addToNoteByName(textElementToAdd, noteNameToBeCreated, true)
        }
    
        step("Then it is successfully added to the note"){
            OmniBoxTestView().navigateToNoteViaPivotButton()
            noteView = NoteTestView()
            _ = noteView.waitForNoteViewToLoad()
            noteNodes = noteView.getNoteNodesForVisiblePart()
        }
        
        step("Then 2 non-empty notes are added"){
            XCTAssertEqual(noteNodes.count, 2)
            XCTAssertNotEqual(noteNodes[0].getStringValue(), emptyString, "note added is an empty string")
        }

    }
    
    func testAddTextToExistingNote() {

        step("Given I create \(noteNameToBeCreated) note"){
            //To be replaced with UITests helper - note creation
            uiMenu.createNote()
            noteView = NoteTestView()
        }
        
        step("Given I open Test page"){
            uiMenu.loadUITestPage3()
            let textElementToAdd = pnsView.staticText(". The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.")
            pnsView.addToNoteByName(textElementToAdd, noteNameToBeCreated)
        }
    
        step("Then it is successfully added to the note"){
            XCTAssertTrue(pnsView.staticText(PnSViewLocators.StaticTexts.addedToPopup.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            OmniBoxTestView().navigateToNoteViaPivotButton()
            _ = noteView.waitForNoteViewToLoad()
            noteNodes = noteView.getNoteNodesForVisiblePart()
        }

        step("Then 2 non-empty notes are added to an empty first one?"){
            XCTAssertTrue(noteNodes.count == 2 || noteNodes.count == 3) //CI specific issue handling
            if noteNodes.count == 2 {
                XCTAssertEqual(noteNodes[0].getStringValue(), "Point And Shoot Test Fixture Cursor")
                XCTAssertEqual(noteNodes[1].getStringValue(), "The pointer hotspot is the active pixel of the pointer, used to target a click or drag. The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.[9][10][11]")
            } else {
                XCTAssertEqual(noteNodes[0].getStringValue(), emptyString)
                XCTAssertEqual(noteNodes[1].getStringValue(), "Point And Shoot Test Fixture Cursor")
                XCTAssertEqual(noteNodes[2].getStringValue(), "The pointer hotspot is the active pixel of the pointer, used to target a click or drag. The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.[9][10][11]")
            }
        }
        
    }
    
    func testAddTextUsingNotes() {
        
        step("Given I create \(noteNameToBeCreated) note"){
            //To be replaced with UITests helper - note creation
            uiMenu.createNote()
            noteView = NoteTestView()
        }
        
        step("Given I open Test page"){
            uiMenu.loadUITestPage3()
        }
        
        step ("When I collect a text via PnS"){
            let textElementToAdd = pnsView.staticText(". The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.")
            pnsView.addToNoteByName(textElementToAdd, noteNameToBeCreated)
        }

        step("Then it is successfully added to the note"){
            OmniBoxTestView().navigateToNoteViaPivotButton()
            _ = noteView.waitForNoteViewToLoad()
            noteNodes = noteView.getNoteNodesForVisiblePart()
            XCTAssert(noteNodes.count == 2 || noteNodes.count == 3) //CI specific issue handling
        }

    }
    
    func testCollectImage() {
        
        step("Given I create \(noteNameToBeCreated) note"){
            uiMenu.createNote()
        }
        
        step ("Then I successfully collect gif"){
            uiMenu.loadUITestPage2()
            let gifItemToAdd = pnsView.image("File:Beam mode 2.gif")
            pnsView.addToNoteByName(gifItemToAdd, noteNameToBeCreated)
            noteView = webView.openDestinationNote()
            XCTAssertTrue(waitForCountValueEqual(timeout: noteView.implicitWaitTimeout, expectedNumber: 1, elementQuery: noteView!.getImageNotesElementsQuery()), "Image note didn't appear within \(noteView.implicitWaitTimeout) seconds")
        }

        step ("Then I successfully collect image"){
            uiMenu.loadUITestPage4()
            let imageItemToAdd = pnsView.image("forest")
            pnsView.addToNoteByName(imageItemToAdd, noteNameToBeCreated)
            webView.openDestinationNote()
            XCTAssertTrue(waitForCountValueEqual(timeout: noteView!.implicitWaitTimeout, expectedNumber: 2, elementQuery: noteView.getImageNotesElementsQuery()), "Image note didn't appear within \(noteView.implicitWaitTimeout) seconds")
        }

    }
    
    func testCollectVideo() throws {
        uiMenu.loadUITestPageMedia()
        
        let itemToCollect = pnsView.app.groups.containing(.button, identifier:"Play Video").children(matching: .group).element.children(matching: .group).element
        pnsView.addToTodayNote(itemToCollect)

        step ("Then switch to journal"){
            noteView = OmniBoxTestView().navigateToNoteViaPivotButton()
            journalView.waitForJournalViewToLoad()
        }

        step ("Then the note contains video link"){
            let expectedContent = "Beam.app/Contents/Resources/video.mov"
            noteNodes = noteView.getNoteNodesForVisiblePart()
            XCTAssertEqual(noteNodes.count, 2)
            let videoNote = noteNodes[1].getStringValue()
            XCTAssertTrue(videoNote.contains(expectedContent), "'\(videoNote)' note doesn't contain:\(expectedContent)")
        }
    }
    
    func testCollectSVG() throws {

        uiMenu.loadUITestSVG()
        uiMenu.resetCollectAllert()
        webView.waitForWebViewToLoad()
        
        step ("THEN SVG image is succeffully captured"){
            let itemToCollect = webView.image("svgimage")
            pnsView.addToTodayNote(itemToCollect)
            noteView = webView.openDestinationNote()
            XCTAssertTrue(waitForCountValueEqual(timeout: noteView!.implicitWaitTimeout, expectedNumber: 1, elementQuery: noteView.getImageNotesElementsQuery()), "Image note didn't appear within \(noteView.implicitWaitTimeout) seconds")
        }
        //Blocked by https://linear.app/beamapp/issue/BE-4180/empty-node-item-is-added-to-a-note-when-capturing-svg-with-no-height
        /*step ("THEN SVG image without weight and height is succeffully captured"){
            let itemToCollect = webView.image("nowidthheightsvgimage")
            pnsView.addToTodayNote(itemToCollect)
            noteView = webView.openDestinationNote()
            XCTAssertTrue(waitForCountValueEqual(timeout: noteView!.implicitWaitTimeout, expectedNumber: 2, elementQuery: noteView.getImageNotesElementsQuery()), "Image note didn't appear within \(noteView.implicitWaitTimeout) seconds")
        }*/
        
        step ("THEN partially SVG image is failed to be captured"){
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            let itemToCollect = webView.image("partialsvgimage")
            _ = itemToCollect.waitForExistence(timeout: pnsView.minimumWaitTimeout)
            XCTAssertTrue(pnsView.addToTodayNote(itemToCollect).getSendBugReportButtonElement().waitForExistence(timeout: pnsView.minimumWaitTimeout))
        }
    }

    func testFailedToCollect() throws {
        // If this test is flakey, make sure browsing collect is disabled first
        step ("When the journal is first loaded the note is empty by default"){
            uiMenu.resetCollectAllert()
            noteView = NoteTestView()
            let beforeNoteNodes = noteView.getNoteNodesForVisiblePart()
            XCTAssertEqual(beforeNoteNodes.count, 1)
            XCTAssertEqual(beforeNoteNodes[0].getStringValue(), emptyString)
            uiMenu.loadUITestPageMedia()
            let itemToCollect = pnsView.app.windows.groups["Audio Controls"].children(matching: .group).element(boundBy: 1).children(matching: .slider).element
            pnsView.addToTodayNote(itemToCollect)
        }


        step ("Then Failed to collect message appears"){
            pnsView.passFailedToCollectPopUpAlert()
            XCTAssertTrue(pnsView.staticText(PnSViewLocators.StaticTexts.failedCollectPopup.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            OmniBoxTestView().navigateToNoteViaPivotButton()
            journalView.waitForJournalViewToLoad()
        }


        step ("Then the note is still empty"){
            noteNodes = NoteTestView().getNoteNodesForVisiblePart()
            XCTAssertEqual(noteNodes.count, 1)
            XCTAssertTrue(noteNodes[0].getStringValue() == emptyString || noteNodes[0].getStringValue() == "Media Player Test Page") //CI specific issue handling
        }
    }
    
    func testCollectFullPage() {
        launchApp()
        let expectedNoteText = "Point And Shoot Test Fixture Cursor"
        
        step ("Given I open Test page"){
            uiMenu.loadUITestPage3()
        }
        
        step ("When I collect full page"){
            shortcutHelper.shortcutActionInvoke(action: .collectFullPage)
            pnsView.waitForCollectPopUpAppear()
            pnsView.typeKeyboardKey(.enter)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step ("Then I see \(expectedNoteText) as collected link"){
            noteView = NoteTestView()
            noteView.waitForNoteViewToLoad()
            noteNodes = noteView.getNoteNodesForVisiblePart()
            //To be refactored once BE-2117 merged
            XCTAssertEqual(noteNodes.count, 1)
            XCTAssertEqual(noteNodes[0].getStringValue(), expectedNoteText)
        }

    }
    
    func testFramePositionPlacementOnSelect() {

        let helper = BeamUITestsHelper(journalView.app)
        uiMenu.resizeWindowLandscape()
        uiMenu.loadUITestPage1()
        let searchText = "The True Story Of Kanye West's \"Ultralight Beam,\" As Told By Fonzworth Bentley"
        let parentElement = pnsView.staticText(searchText).firstMatch

        step ("When I click and drag between start and end of full text"){
            webView.clickStartOfTextAndDragTillEnd(textIdentifier: searchText, elementToPerformAction: parentElement)
        }

        step ("Then I see Shoot Frame Selection after Option button press"){
            pnsView.pressOptionButtonFor(seconds: 1)
            XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
        }
        
        /*step (""){
            
        }("TBD") //Scroll to be fixed
        webView.scrollDown()
        XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
        
        step (""){
            
        }("TBD")
        webView.scrollUp()
        XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))*/
        
        step ("And I see Shoot Frame Selection remained after zoom in"){
            pnsView.zoomIn(numberOfTimes: 3)
            XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
        }

        step ("And I see Shoot Frame Selection remained after zoom out"){
            pnsView.zoomOut(numberOfTimes: 3)
            XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
        }

        step ("And I see Shoot Frame Selection remained after window resize"){
            uiMenu.resizeWindowPortrait()
            XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
        }

        step ("And after shooting then pressing and releasing option shouldn't keep shootframe active"){
            helper.addNote()
            pnsView.pressOptionButtonFor(seconds: 1)
            XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(0))
        }

    }
    
    func testFramePositionPlacementOnPoint() throws {
        //Point "frame position placement"
        let helper = BeamUITestsHelper(journalView.app)
        var center: XCUICoordinate?
        step ("Given I open test page in landscape mode"){
            uiMenu
                .resizeWindowLandscape()
                .loadUITestPage1()
            
            let searchText = "The True Story Of Kanye West's \"Ultralight Beam,\" As Told By Fonzworth Bentley"
            let parent = webView.staticText(searchText).firstMatch

            center = webView.getCenterOfElement(element: parent)
            // click at middle of searchText to focus on page
            center!.click()
        }

        // Hold option to enable point mode
        step ("When I hold OPTION"){
            XCUIElement.perform(withKeyModifiers: .option) {
                // While holding option
                step ("Then point Frame is available"){
                    center!.hover()
                    XCTAssertTrue(pnsView.assertNumberOfAvailablePointFrames(1))
                }
                
                step ("And point Frame is available after Zooming In"){
                    pnsView.zoomIn(numberOfTimes: 3)
                    XCTAssertTrue(pnsView.assertNumberOfAvailablePointFrames(1))
                }
                
                step ("And point Frame is available after Zooming Out"){
                    pnsView.zoomOut(numberOfTimes: 3)
                    XCTAssertTrue(pnsView.assertNumberOfAvailablePointFrames(1))
                }
        
            // Scroll page
            /*step (""){
            
        }("TBD")
            webView.scrollDown()
            pnsView.assertFramePositions(searchText: searchText, identifier: identifierForPositionsAssertion)*/
            
            // Resize window
                step ("And point Frame is available after resizing"){
                    uiMenu.resizeWindowPortrait()
                    center!.hover()
                    XCTAssertTrue(pnsView.assertNumberOfAvailablePointFrames(1))
                    // Shoot
                    center!.click()
                    // Release option
                }
            }
        }

        step ("TBD"){
            // PointAndShootPopup is now also visible
            XCTAssertTrue(pnsView.assertNumberOfAvailablePointFrames(1))

            // Add to today's note
            let noteTitle = "Ultralight Beam"
            helper.addNote(noteTitle: noteTitle)

            // Assert note association
            XCUIElement.perform(withKeyModifiers: .option) {
                // While holding option, hover text
                // step (""){
                    // center.hover()
                    // pnsView.assertFramePositions(searchText: searchText, identifier: identifierForPositionsAssertion)
                //}("TBD")
                
            }
        }
    }
    
    func SKIPtestDismissShootCardPicker() throws {
        try XCTSkipIf(true, "Skipped due to PointFrame cannot be detected BE-2591")
       //Shoot "dismiss shootCardPicker by clicking on page and pressing escape"
       launchApp()
       uiMenu.loadUITestPage1()
       let searchText = "Ultralight Beam, Kanye West"
       let parent = webView.app.webViews.containing(.staticText,
                                            identifier: searchText).element
       
        let parentElement = webView.staticText(searchText).firstMatch

       // click and drag between start and end of full text
       step ("TBD"){
           webView.clickStartOfTextAndDragTillEnd(textIdentifier: searchText, elementToPerformAction: parentElement)
        }
       
       // click and drag between start and end of full text
       let child = parent.staticTexts[searchText]
       
       // Press option once to enable shoot mode
       step ("TBD"){
           pnsView.pressOptionButtonFor(seconds: 1)
           XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 1, elementQuery: pnsView.getShootFrameSelection()))
        }

       step ("TBD"){
           let emptyLocation = child.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -1))
           emptyLocation.click()
           XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 0, elementQuery: pnsView.getShootFrameSelection()))
        }

       step ("TBD"){
           webView.clickStartOfTextAndDragTillEnd(textIdentifier: searchText, elementToPerformAction: parentElement)
           // Press option once to enable shoot mode
           pnsView.pressOptionButtonFor(seconds: 1)
           XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 1, elementQuery: pnsView.getShootFrameSelection()))
       }

       step ("TBD"){
          // dismiss shootCardPicker with escape
          webView.typeKeyboardKey(.escape)
          XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 0, elementQuery: pnsView.getShootFrameSelection()))
        }
    }
    
    
    func testOpensShootCardPickerWithoutNavigatingPage() {
        //"opens ShootCardPicker and not navigate the page"
        step ("Given I open a test page"){
            uiMenu.loadUITestPage1()
        }

        step ("Then I'm not redireceted after pointing a URL"){
            // Press option once to enable pointing mode
            XCUIElement.perform(withKeyModifiers: .option) {
                sleep(1)
                // get the url before clicking
                let beforeUrl = webView.getTabUrlAtIndex(index: 0)
                webView.staticText("I-Beam").clickOnExistence()
                // compare with url after clicking
                XCTAssertEqual(beforeUrl, webView.getTabUrlAtIndex(index: 0))
            }
        }
    }
    
    
    func testNavigateLinksInCollectedText() throws {
        //"can navigate links in collected text"
        let helper = BeamUITestsHelper(journalView.app)

        let journalScrollView = journalView.app.scrollViews["journalView"]

        let journalChildren = journalScrollView.children(matching: .textView)
            .matching(identifier: "TextNode")
        uiMenu.loadUITestPage3()

        let prefix = "Go to "
        let linkText = "UITests-1"

        // Get locations of the text
        let parent = journalView.app.webViews.containing(.staticText, identifier: linkText).element
        let textElement = parent.staticTexts[prefix].firstMatch
        pnsView.addToTodayNote(textElement)
        // Confirm text is saved in Journal
        helper.showJournal()
        let title3Predicate = NSPredicate(format: "value = %@", prefix + linkText)
        XCTAssertTrue(journalChildren.element(matching: title3Predicate).waitForExistence(timeout: 4))
        XCTAssertEqual(journalChildren.count, 2)
        // tap on collected sublink (end of new bullet)
        let linkWord = journalChildren.element(matching: title3Predicate).buttons[linkText]
        XCTAssertTrue(linkWord.waitForExistence(timeout: 5))
        linkWord.tapInTheMiddle()

        // tap on a link in the page, should be added to opened bullet
        let page2Link = journalView.app.webViews.staticTexts["I-Beam"].firstMatch
        XCTAssertTrue(page2Link.waitForExistence(timeout: 4))
        page2Link.tap()
        helper.showJournal()
    }
}
