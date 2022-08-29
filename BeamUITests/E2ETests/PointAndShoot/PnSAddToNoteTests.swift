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
    let noteView = NoteTestView()
    var noteNodes: [XCUIElement]!
    var journalView: JournalTestView!

    override func setUp() {
        journalView = launchApp()
        uiMenu.resizeSquare1000()
    }
    
    func SKIPtestAddTextToTodaysNote() throws {
        try XCTSkipIf(true, "Skipped so far, to replace NavigationCollectUITests")
        let expectedItemText1 = uiTestPageThree
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
        testrailId("C1061, C1014, C747")
        step("Given I open Test page"){
            uiMenu.loadUITestPage3()
            let textElementToAdd = pnsView.staticText(" capital letter \"I\". The purpose of this cursor is to indicate that the text beneath the cursor can be highlighted, and sometime")
            pnsView.addToNoteByName(textElementToAdd, noteNameToBeCreated, true)
        }
    
        step("Then it is successfully added to the note"){
            OmniBoxTestView().navigateToNoteViaPivotButton()
            XCTAssertTrue(noteView.waitForNoteViewToLoad())
            noteNodes = noteView.getNoteNodesForVisiblePart()
        }
        
        step("Then 2 non-empty notes are added"){
            XCTAssertEqual(noteNodes.count, 2)
            XCTAssertNotEqual(noteNodes[0].getStringValue(), emptyString, "note added is an empty string")
        }
    }
    
    func testAddTextToExistingNote() {
        testrailId("C1062, C1014, C997")
        step("Given I create \(noteNameToBeCreated) note"){
            uiMenu.createNote()
        }
        
        step("Given I open Test page"){
            uiMenu.loadUITestPage3()
            let textElementToAdd = pnsView.staticText(". The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.")
            pnsView.addToNoteByName(textElementToAdd, noteNameToBeCreated)
        }
    
        step("Then it is successfully added to the note"){
            XCTAssertTrue(pnsView.staticText(PnSViewLocators.StaticTexts.addedToPopup.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            OmniBoxTestView().navigateToNoteViaPivotButton()
            XCTAssertTrue(noteView.waitForNoteViewToLoad())
            noteNodes = noteView.getNoteNodesForVisiblePart()
        }

        step("Then 2 non-empty notes are added to an empty first one?"){
            let expectedTextNodeValue = "The pointer hotspot is the active pixel of the pointer, used to target a click or drag. The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.[9][10][11]"
            XCTAssertTrue(noteNodes.count == 2 || noteNodes.count == 3) //CI specific issue handling
            if noteNodes.count == 2 {
                XCTAssertEqual(noteNodes[0].getStringValue(), uiTestPageThree)
                XCTAssertEqual(noteNodes[1].getStringValue(), expectedTextNodeValue)
            } else {
                XCTAssertEqual(noteNodes[0].getStringValue(), emptyString)
                XCTAssertEqual(noteNodes[1].getStringValue(), uiTestPageThree)
                XCTAssertEqual(noteNodes[2].getStringValue(), expectedTextNodeValue)
            }
        }
    }
    
    func testAddTextUsingNotes() {
        testrailId("C1065")
        step("Given I create \(noteNameToBeCreated) note"){
            //To be replaced with UITests helper - note creation
            uiMenu.createNote()
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
        testrailId("C1007")
        step("Given I create \(noteNameToBeCreated) note"){
            uiMenu.createNote()
        }
        
        step ("Then I successfully collect gif"){
            uiMenu.loadUITestPage2()
            let gifItemToAdd = pnsView.image("File:Beam mode 2.gif")
            pnsView.addToNoteByName(gifItemToAdd, noteNameToBeCreated)
            webView.openDestinationNote()
            XCTAssertTrue(waitForCountValueEqual(timeout: noteView.implicitWaitTimeout, expectedNumber: 1, elementQuery: noteView.getImageNotesElementsQuery()), "Image note didn't appear within \(noteView.implicitWaitTimeout) seconds")
        }

        step ("Then I successfully collect image"){
            uiMenu.loadUITestPage4()
            let imageItemToAdd = pnsView.image("forest")
            pnsView.addToNoteByName(imageItemToAdd, noteNameToBeCreated)
            webView.openDestinationNote()
            XCTAssertTrue(waitForCountValueEqual(timeout: noteView.implicitWaitTimeout, expectedNumber: 2, elementQuery: noteView.getImageNotesElementsQuery()), "Image note didn't appear within \(noteView.implicitWaitTimeout) seconds")
        }

    }
    
    func testCollectVideo() throws {
        testrailId("C1006")
        step ("WHEN I collect a video to Today's note"){
            uiMenu.loadUITestPageMedia()
            let itemToCollect = pnsView.app.groups.containing(.button, identifier:"Play Video").children(matching: .group).element.children(matching: .group).element
            pnsView.addToTodayNote(itemToCollect)
        }

        step ("WHEN I switch to journal"){
            OmniBoxTestView().navigateToNoteViaPivotButton()
            journalView.waitForJournalViewToLoad()
        }

        step ("THEN the note contains video link"){
            let expectedContent = "Beam.app/Contents/Resources/video.mov"
            noteNodes = noteView.getNoteNodesForVisiblePart()
            XCTAssertEqual(noteNodes.count, 2)
            let videoNote = noteNodes[1].getStringValue()
            XCTAssertTrue(videoNote.contains(expectedContent), "'\(videoNote)' note doesn't contain:\(expectedContent)")
        }
    }
    
    func testCollectSVGToNote() {
        testrailId("C1066")
        step ("WHEN I load a web page with SVG image"){
            uiMenu.loadUITestSVG()
            uiMenu.resetCollectAllert()
            webView.waitForWebViewToLoad()
        }
        
        step ("THEN SVG image is succeffully captured"){
            let itemToCollect = webView.image("svgimage")
            pnsView.addToTodayNote(itemToCollect)
            webView.openDestinationNote()
            XCTAssertTrue(waitForCountValueEqual(timeout: noteView.implicitWaitTimeout, expectedNumber: 1, elementQuery: noteView.getImageNotesElementsQuery()), "Image note didn't appear within \(noteView.implicitWaitTimeout) seconds")
        }
    }

    // When example content found that triggers this condition enable UItest: https://linear.app/beamapp/issue/BE-5203/find-failed-to-collect-example-for-ui-test
    /*func testFailedToCollect() {
        testrailId("C1063")
        // If this test is flakey, make sure browsing collect is disabled first
        step ("When the journal is first loaded the note is empty by default"){
            uiMenu.resetCollectAllert()
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
            noteNodes = noteView.getNoteNodesForVisiblePart()
            XCTAssertEqual(noteNodes.count, 1)
            XCTAssertTrue(noteNodes[0].getStringValue() == emptyString || noteNodes[0].getStringValue() == "Media Player Test Page") //CI specific issue handling
        }
    }*/
    
    func testCollectFullPage() {
        testrailId("C1064")
        let expectedNoteText = uiTestPageThree
        
        step ("Given I open Test page"){
            uiMenu.loadUITestPage3()
        }
        
        testrailId("C508, C935")
        step ("When I collect full page"){
            shortcutHelper.shortcutActionInvoke(action: .collectFullPage)
            pnsView.waitForCollectPopUpAppear()
            pnsView.typeKeyboardKey(.enter)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step ("Then I see \(expectedNoteText) as collected link"){
            noteView.waitForNoteViewToLoad()
            noteNodes = noteView.getNoteNodesForVisiblePart()
            //To be refactored once BE-2117 merged
            XCTAssertEqual(noteNodes.count, 1)
            XCTAssertEqual(noteNodes[0].getStringValue(), expectedNoteText)
        }

    }
    
    func testFramePositionPlacementOnSelect() {
        testrailId("C927")
        let helper = BeamUITestsHelper(journalView.app)
        let searchText = "The True Story Of Kanye West's \"Ultralight Beam,\" As Told By Fonzworth Bentley"
        let parentElement = pnsView.staticText(searchText).firstMatch

        step ("GIVEN I load a test webpage"){
            uiMenu.resizeWindowLandscape()
            uiMenu.loadUITestPage1()
        }

        step ("When I click and drag between start and end of full text"){
            webView.clickStartOfTextAndDragTillEnd(textIdentifier: searchText, elementToPerformAction: parentElement)
        }

        testrailId("C934")
        step ("Then I see Shoot Frame Selection after Option button press"){
            pnsView.pressOptionButtonFor(seconds: 1)
            XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
        }

        step ("Then I see Shoot Frame Selection on scroll up and down"){
            webView.scrollDown()
            XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
            webView.scrollUp()
            XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
        }

        testrailId("C1142")
        step ("And I see Shoot Frame Selection remained after zoom in"){
            pnsView.zoomIn(numberOfTimes: 3)
            XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
        }

        testrailId("C1142")
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

    
    func testFramePositionPlacementOnPoint() {
        testrailId("C927")
        //Point "frame position placement"
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

        step ("THEN Number of available point frames is correct"){
            XCTAssertTrue(pnsView.assertNumberOfAvailablePointFrames(1))
        }
    }
    
    func testDismissShootCardPicker() {
        testrailId("C1005")
        let searchText = "Ultralight Beam, Kanye West"
        let textElementToShoot = webView.staticText(searchText).firstMatch

        step ("WHEN I select a text on a test page"){
            uiMenu.loadUITestPage1()
            webView.clickStartOfTextAndDragTillEnd(textIdentifier: searchText, elementToPerformAction: textElementToShoot)
        }
        
        step ("WHEN I press option once to enable shoot mode"){
            pnsView.pressOptionButtonFor(seconds: 1)
            XCTAssertTrue(pnsView.waitForCollectPopUpAppear())
            XCTAssertTrue(pnsView.assertPointFrameExists())
        }

        step ("THEN Capture pop-up is dismissed with a click on a web page"){
            let emptyLocation = textElementToShoot.coordinate(withNormalizedOffset: CGVector(dx:  0.5, dy: -2))
            emptyLocation.click()
            XCTAssertTrue(waitForDoesntExist(pnsView.textField(PnSViewLocators.TextFields.shootCardPickerTextField.accessibilityIdentifier)))
            XCTAssertTrue(waitForDoesntExist(pnsView.otherElement(PnSViewLocators.Other.pointFrame.accessibilityIdentifier)))
         }

        step ("WHEN I invoke Capture frame"){
            webView.clickStartOfTextAndDragTillEnd(textIdentifier: searchText, elementToPerformAction: textElementToShoot)
            // Press option once to enable shoot mode
            pnsView.pressOptionButtonFor(seconds: 1)
            XCTAssertTrue(pnsView.waitForCollectPopUpAppear())
            XCTAssertTrue(pnsView.assertPointFrameExists())
        }

        step ("THEN Capture pop-up is dismissed with escape button click"){
           webView.typeKeyboardKey(.escape)
            XCTAssertTrue(waitForDoesntExist(pnsView.textField(PnSViewLocators.TextFields.shootCardPickerTextField.accessibilityIdentifier)))
            XCTAssertTrue(waitForDoesntExist(pnsView.otherElement(PnSViewLocators.Other.pointFrame.accessibilityIdentifier)))
        }
    }
    
    
    func testOpensShootCardPickerWithoutNavigatingPage() {
        testrailId("C997")
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
    
    
    func testNavigateLinksInCollectedText() {
        testrailId("C1067")
        let prefix = "Go to "
        let linkText = "UITests-1"
        let textToPoint = journalView.app.webViews.containing(.staticText, identifier: linkText).element.staticTexts[prefix].firstMatch
        let linkElement = journalView.getTextNodeMatching(value: prefix + linkText).buttons[linkText]
        let pageToBeOpenedAfterLinkClick = webView.staticText("I-Beam")
        
        step("GIVEN I load a test page") {
            uiMenu.loadUITestPage3()
        }
        
        step("WHEN I collect a text to Today's note") {
            pnsView.addToTodayNote(textToPoint)
        }
        
        step("WHEN I switch to Journal") {
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }

        step("THEN I switch to Journal") {
            XCTAssertTrue(journalView.isTextNodeDisplayed(matchingValue: prefix + linkText))
            XCTAssertEqual(journalView.getNoteNodesForVisiblePart().count, 2)
            XCTAssertTrue(linkElement.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("WHEN I tap on a link") {
            linkElement.tapInTheMiddle()
        }

        step("THEN I'm successfully redirected to a correct web page") {
            XCTAssertTrue(pageToBeOpenedAfterLinkClick.waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
    }
}
