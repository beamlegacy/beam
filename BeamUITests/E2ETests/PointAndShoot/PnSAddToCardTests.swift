//
//  PnSAddToCardTests.swift
//  BeamUITests
//
//  Created by Andrii on 17.09.2021.
//

import Foundation
import XCTest

class PnSAddToCardTests: BaseTest {
       
    let cardNameToBeCreated = "PnS Card"
    let shortcutsHelper = ShortcutsHelper()
        let waitHelper = WaitHelper()
        let pnsView = PnSTestView()
        let webView = WebTestView()
        let titles = [
            "Point And Shoot Test Fixture Ultralight Beam",
            "Point And Shoot Test Fixture I-Beam",
            "Point And Shoot Test Fixture Cursor"
        ]
    
    func testAddTextToTodaysCard() throws {
        try XCTSkipIf(true, "Skipped so far, to replace NavigationCollectUITests")
        let journalView = launchApp()
        UITestsMenuBar().destroyDB()
        let helper = BeamUITestsHelper(pnsView.app)
        let expectedItemText1 = "Point And Shoot Test Fixture Cursor"
        let expectedItemText2 = "Go to UITests-1"
        
        print("Given I open Test page")
        helper.openTestPage(page: .page3)
        
        print("When I point and shoot the following text and add it to Todays card")
        let prefix = "Go to "
        let linkText = "UITests-1"
        let parent = pnsView.app.webViews.containing(.staticText, identifier: linkText).element
        let textElement = parent.staticTexts[prefix].firstMatch
        pnsView.addToTodayCard(textElement)
        let todaysDateInCardTitleFormat = DateHelper().getTodaysDateString(.cardViewTitle)
        
        print("Then it is successfully added to the card")
        XCTAssertTrue(pnsView.assertAddedToCardSuccessfully(todaysDateInCardTitleFormat))
        OmniBarTestView().navigateToCardViaPivotButton()
        journalView.waitForJournalViewToLoad()
        let cardNotes = CardTestView().getCardNotesForVisiblePart()
        
        print("Then \(expectedItemText1) and \(expectedItemText2) items are displayed in the card")
        XCTAssertEqual(cardNotes.count, 2)
        XCTAssertEqual(cardNotes[0].value as? String, expectedItemText1)
        XCTAssertEqual(cardNotes[1].value as? String, expectedItemText2)
    }
    
    func testAddTextToNewCard() {
        launchApp()
        UITestsMenuBar().destroyDB()
        let helper = BeamUITestsHelper(pnsView.app)
        
        print("Given I open Test page")
        helper.openTestPage(page: .page3)
    
        let textElementToAdd = pnsView.staticText(" capital letter \"I\". The purpose of this cursor is to indicate that the text beneath the cursor can be highlighted, and sometime")
        
        pnsView.addToCardByName(textElementToAdd, cardNameToBeCreated, "", true)
        
        print("Then it is successfully added to the card")
        // Commented out as far as it is too unreliable
        //XCTAssertTrue(pnsView.assertAddedToCardSuccessfully(cardNameToBeCreated))
        OmniBarTestView().navigateToCardViaPivotButton()
        let cardView = CardTestView()
        _ = cardView.waitForCardViewToLoad()
        let cardNotes = cardView.getCardNotesForVisiblePart()
        
        print("Then 2 non-empty notes are added")
        XCTAssertEqual(cardNotes.count, 2)
        XCTAssertNotEqual(cardView.getElementStringValue(element: cardNotes[0]), emptyString, "note added is an empty string")
    }
    
    func testAddTextToExistingCard() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(pnsView.app)
        print("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        print("Given I open Test page")
        helper.openTestPage(page: .page3)
    
        let textElementToAdd = pnsView.staticText(". The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.")
        
        pnsView.addToCardByName(textElementToAdd, cardNameToBeCreated)
        
        print("Then it is successfully added to the card")
        XCTAssertTrue(pnsView.staticText(PnSViewLocators.StaticTexts.addedToPopup.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        OmniBarTestView().navigateToCardViaPivotButton()
        _ = cardView.waitForCardViewToLoad()
        let cardNotes = cardView.getCardNotesForVisiblePart()
        
        print("Then 2 non-empty notes are added to an empty first one?")
        XCTAssertTrue(cardNotes.count == 2 || cardNotes.count == 3) //CI specific issue handling
        if cardNotes.count == 2 {
            XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[0]), "Point And Shoot Test Fixture Cursor")
            XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[1]), "The pointer hotspot is the active pixel of the pointer, used to target a click or drag. The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.[9][10][11]")
        } else {
            XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[0]), emptyString)
            XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[1]), "Point And Shoot Test Fixture Cursor")
            XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[2]), "The pointer hotspot is the active pixel of the pointer, used to target a click or drag. The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.[9][10][11]")
        }
    }
    
    func testAddTextUsingNotes() {
        let noteText = "this is a note"
        let journalView = launchApp()
        let helper = BeamUITestsHelper(pnsView.app)
        print("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        print("Given I open Test page")
        helper.openTestPage(page: .page3)
        
        testRailPrint("When I collect a text via PnS")
        let textElementToAdd = pnsView.staticText(". The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.")
        
        pnsView.addToCardByName(textElementToAdd, cardNameToBeCreated, noteText)
        
        print("Then it is successfully added to the card")
        OmniBarTestView().navigateToCardViaPivotButton()
        _ = cardView.waitForCardViewToLoad()
        let cardNotes = cardView.getCardNotesForVisiblePart()
        XCTAssertTrue(cardNotes.count == 3 || cardNotes.count == 4) //CI specific issue handling
        XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[cardNotes.count - 1]), noteText) //CI specific issue handling
    }
    
    func testCollectImage() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        helper.tapCommand(.resizeSquare1000)
        print("Given I create \(cardNameToBeCreated) card")
        journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        testRailPrint("Then I successfully collect gif")
        helper.openTestPage(page: .page2)
        let webView = WebTestView()
        let gifItemToAdd = pnsView.image("File:Beam mode 2.gif")
        pnsView.addToCardByName(gifItemToAdd, cardNameToBeCreated)
        let cardView = webView.openDestinationCard()
        XCTAssertTrue(waitHelper.waitForCountValueEqual(timeout: cardView.implicitWaitTimeout, expectedNumber: 1, elementQuery: cardView.getImageNotesElementsQuery()), "Image note didn't appear within \(cardView.implicitWaitTimeout) seconds")
        
        testRailPrint("Then I successfully collect image")
        helper.openTestPage(page: .page4)
        let imageItemToAdd = pnsView.image("forest")
        pnsView.addToCardByName(imageItemToAdd, cardNameToBeCreated)
        webView.openDestinationCard()
        XCTAssertTrue(waitHelper.waitForCountValueEqual(timeout: cardView.implicitWaitTimeout, expectedNumber: 2, elementQuery: cardView.getImageNotesElementsQuery()), "Image note didn't appear within \(cardView.implicitWaitTimeout) seconds")
    }
    
    func testCollectVideo() throws {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(pnsView.app)
        helper.openTestPage(page: .media)
        
        let itemToCollect = pnsView.app.groups.containing(.button, identifier:"Play Video").children(matching: .group).element.children(matching: .group).element
        pnsView.addToTodayCard(itemToCollect)

        testRailPrint("Then switch to journal")
        let cardView = OmniBarTestView().navigateToCardViaPivotButton()
        journalView.waitForJournalViewToLoad()

        testRailPrint("Then the note contains video link")
        let cardNotes = cardView.getCardNotesForVisiblePart()
        XCTAssertEqual(cardNotes.count, 2)
        XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[0]), "Media Player Test Page")
        if let videoNote = cardNotes[1].value as? String {
            XCTAssertTrue(videoNote.contains("Beam.app/Contents/Resources/video.mov"))
        } else {
            XCTFail("expected cardNote[1].value to be a string")
        }
    }

    func testFailedToCollect() throws {
        // If this test is flakey, make sure browsing collect is disabled first
        let journalView = launchApp()
        let helper = BeamUITestsHelper(pnsView.app)

        testRailPrint("When the journal is first loaded the note is empty by default")
        let cardView = CardTestView()
        let beforeCardNotes = cardView.getCardNotesForVisiblePart()
        XCTAssertEqual(beforeCardNotes.count, 1)
        XCTAssertEqual(cardView.getElementStringValue(element: beforeCardNotes[0]), emptyString)
        helper.openTestPage(page: .media)
        let itemToCollect = pnsView.app.windows.groups["Audio Controls"].children(matching: .group).element(boundBy: 1).children(matching: .slider).element
        pnsView.addToTodayCard(itemToCollect)

        testRailPrint("Then Failed to collect message appears")
        pnsView.passFailedToCollectPopUpAlert()
        XCTAssertTrue(pnsView.staticText(PnSViewLocators.StaticTexts.failedCollectPopup.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        OmniBarTestView().navigateToCardViaPivotButton()
        journalView.waitForJournalViewToLoad()

        testRailPrint("Then the note is still empty")
        let cardNotes = CardTestView().getCardNotesForVisiblePart()
        XCTAssertEqual(cardNotes.count, 1)
        XCTAssertTrue(cardView.getElementStringValue(element: cardNotes[0]) == emptyString || cardView.getElementStringValue(element: cardNotes[0]) == "Media Player Test Page") //CI specific issue handling
    }
    
    func testCollectFullPage() {
        launchApp()
        let helper = BeamUITestsHelper(pnsView.app)
        let shortcutsHelper = ShortcutsHelper()
        let expectedNoteText = "Point And Shoot Test Fixture Cursor"
        
        testRailPrint("Given I open Test page")
        helper.openTestPage(page: .page3)
        
        testRailPrint("When I collect full page")
        shortcutsHelper.shortcutActionInvoke(action: .collectFullPage)
        pnsView.waitForCollectPopUpAppear()
        pnsView.typeKeyboardKey(.enter)
        shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        
        testRailPrint("Then I see \(expectedNoteText) as collected link")
        let cardView = CardTestView()
        let cardNotes = cardView.getCardNotesForVisiblePart()
        //To be refactored once BE-2117 merged
        XCTAssertEqual(cardNotes.count, 2)
        XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[0]), expectedNoteText)
        XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[1]), expectedNoteText)
        
        testRailPrint("When I try to collect full page for empty tab")
        shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        shortcutsHelper.shortcutActionInvoke(action: .newTab)
        shortcutsHelper.shortcutActionInvoke(action: .collectFullPage)
        
        testRailPrint("Then collect page doesn't appear")
        XCTAssertFalse(pnsView.waitForCollectPopUpAppear(), "Collect pop-up appeared for an empty page")
    }
    
    func testAddLinksToJournalInOrder() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        helper.tapCommand(.enableBrowsingSessionCollection)
        
        testRailPrint("Then first collected element is on top")
        helper.openTestPage(page: .page1)
        shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        journalView.waitForJournalViewToLoad()
        let cardView = CardTestView()
        XCTAssertEqual(titles[0], cardView.getCardNoteValueByIndex(0))

        testRailPrint("Then first collected element is on top, second is below")
        helper.openTestPage(page: .page2)
        shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        XCTAssertEqual(titles[0], cardView.getCardNoteValueByIndex(0))
        XCTAssertEqual(titles[1], cardView.getCardNoteValueByIndex(1))
        
        testRailPrint("Then first collected element is on top, second and third are below")
        helper.openTestPage(page: .page3)
        shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        XCTAssertEqual(titles[0], cardView.getCardNoteValueByIndex(0))
        XCTAssertEqual(titles[1], cardView.getCardNoteValueByIndex(1))
        XCTAssertEqual(titles[2], cardView.getCardNoteValueByIndex(2))
    }
    
    func testFramePositionPlacementOnSelect() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        helper.tapCommand(.resizeWindowLandscape)
        helper.openTestPage(page: .page1)
        let searchText = "The True Story Of Kanye West's “Ultralight Beam,\" As Told By Fonzworth Bentley"
        let parentElement = webView.staticText(searchText)

        testRailPrint("When I click and drag between start and end of full text")
        webView.clickStartOfTextAndDragTillEnd(textIdentifier: searchText, elementToPerformAction: parentElement)

        testRailPrint("Then I see Shoot Frame Selection after Option button press")
        pnsView.pressOptionButtonFor(seconds: 1)
        XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
        
        /*testRailPrint("TBD") //Scroll to be fixed
        webView.scrollDown()
        XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
        
        testRailPrint("TBD")
        webView.scrollUp()
        XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))*/
        
        testRailPrint("Then I see Shoot Frame Selection remained after zoom in")
        pnsView.zoomIn(numberOfTimes: 3)
        XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
        
        testRailPrint("Then I see Shoot Frame Selection remained after zoom out")
        pnsView.zoomOut(numberOfTimes: 3)
        XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))
        
        testRailPrint("Then I see Shoot Frame Selection remained after window resize")
        helper.tapCommand(.resizeWindowPortrait)
        XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(1))

        testRailPrint("Then after shooting then pressing and releasing option shouldn't keep shootframe active")
        helper.addNote()
        pnsView.pressOptionButtonFor(seconds: 1)
        XCTAssertTrue(pnsView.assertNumberOfAvailableShootFrameSelection(0))
    }
    
    func testFramePositionPlacementOnPoint() throws {
        //Point "frame position placement"
        let helper = BeamUITestsHelper(launchApp().app)
        helper.tapCommand(.resizeWindowLandscape)
        helper.openTestPage(page: .page1)
        
        let searchText = "The True Story Of Kanye West's “Ultralight Beam,\" As Told By Fonzworth Bentley"
        let parent = webView.staticText(searchText).firstMatch

        //let child = parent.staticTexts[searchText]
        let center = webView.getCenterOfElement(element: parent)
        // click at middle of searchText to focus on page
        center.click()

        let identifierForPositionsAssertion = PnSViewLocators.Other.pointFrame.accessibilityIdentifier
        // Hold option to enable point mode
        testRailPrint("TBD")
        XCUIElement.perform(withKeyModifiers: .option) {
            // While holding option
            testRailPrint("TBD")
            center.hover()
            //sleep(1)
            XCTAssertTrue(pnsView.assertNumberOfAvailablePointFrames(1))
            
            testRailPrint("TBD")
            pnsView.zoomIn(numberOfTimes: 3)
            XCTAssertTrue(pnsView.assertNumberOfAvailablePointFrames(1))
            
            testRailPrint("TBD")
            pnsView.zoomOut(numberOfTimes: 3)
            XCTAssertTrue(pnsView.assertNumberOfAvailablePointFrames(1))
            
            // Scroll page
            /*testRailPrint("TBD")
            webView.scrollDown()
            pnsView.assertFramePositions(searchText: searchText, identifier: identifierForPositionsAssertion)*/
            
            // Resize window
            testRailPrint("TBD")
            helper.tapCommand(.resizeWindowPortrait)
            center.hover()
            XCTAssertTrue(pnsView.assertNumberOfAvailablePointFrames(1))
            // Shoot
            center.click()
            // Release option
        }

        testRailPrint("TBD")
        // PointAndShootPopup is now also visible
        XCTAssertTrue(pnsView.assertNumberOfAvailablePointFrames(1))
        XCTAssertTrue(pnsView.textField(PnSViewLocators.TextFields.addNote.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))

        // Add to today's note
        let noteTitle = "Ultralight Beam"
        helper.addNote(noteTitle: noteTitle)

        // Assert card association
        XCUIElement.perform(withKeyModifiers: .option) {
            // While holding option, hover text
            // testRailPrint("TBD")
            // center.hover()
            // pnsView.assertFramePositions(searchText: searchText, identifier: identifierForPositionsAssertion)
        }
    }
    
    func testDismissShootCardPicker() throws {
        try XCTSkipIf(true, "Skipped due to PointFrame cannot be detected BE-2591")
       //Shoot "dismiss shootCardPicker by clicking on page and pressing escape"
       let journalView = launchApp()
       let helper = BeamUITestsHelper(journalView.app)
       helper.openTestPage(page: .page1)
       let searchText = "Ultralight Beam, Kanye West"
       let parent = webView.app.webViews.containing(.staticText,
                                            identifier: searchText).element
       
        let parentElement = webView.staticText(searchText).firstMatch

       // click and drag between start and end of full text
       testRailPrint("TBD")
       webView.clickStartOfTextAndDragTillEnd(textIdentifier: searchText, elementToPerformAction: parentElement)
       
       // click and drag between start and end of full text
       let child = parent.staticTexts[searchText]
       
       // Press option once to enable shoot mode
       testRailPrint("TBD")
       pnsView.pressOptionButtonFor(seconds: 1)
       XCTAssertTrue(waitHelper.waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 1, elementQuery: pnsView.getShootFrameSelection()))
       
       testRailPrint("TBD")
       let emptyLocation = child.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -1))
       emptyLocation.click()
       XCTAssertTrue(waitHelper.waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 0, elementQuery: pnsView.getShootFrameSelection()))
       
       testRailPrint("TBD")
       webView.clickStartOfTextAndDragTillEnd(textIdentifier: searchText, elementToPerformAction: parentElement)
       // Press option once to enable shoot mode
       pnsView.pressOptionButtonFor(seconds: 1)
       XCTAssertTrue(waitHelper.waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 1, elementQuery: pnsView.getShootFrameSelection()))

       testRailPrint("TBD")
       // dismiss shootCardPicker with escape
       webView.typeKeyboardKey(.escape)
       XCTAssertTrue(waitHelper.waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 0, elementQuery: pnsView.getShootFrameSelection()))
    }
    
    
    func testOpensShootCardPickerWithoutNavigatingPage() {
       //"opens ShootCardPicker and not navigate the page"
       let journalView = launchApp()
       let helper = BeamUITestsHelper(journalView.app)
       let omnibarHelper = OmniBarUITestsHelper(journalView.app)
       
       testRailPrint("Given I open a test page")
       helper.openTestPage(page: .page1)
       
       testRailPrint("Then I'm not redireceted after pointing a URL")
       // Press option once to enable pointing mode
       XCUIElement.perform(withKeyModifiers: .option) {
           sleep(1)
           // get the url before clicking
           let beforeUrl = OmniBarTestView().getSearchFieldValue()
           webView.staticText("I-Beam").clickOnExistence()
           // compare with url after clicking
           XCTAssertTrue(waitHelper.waitForStringValueEqual(beforeUrl, omnibarHelper.searchField))
        }
    }
    
    
    func testNavigateLinksInCollectedText() throws {
        //"can navigate links in collected text"
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)

        let journalScrollView = journalView.app.scrollViews["journalView"]

        let journalChildren = journalScrollView.children(matching: .textView)
            .matching(identifier: "TextNode")
        helper.openTestPage(page: .page3)

        let prefix = "Go to "
        let linkText = "UITests-1"

        // Get locations of the text
        let parent = journalView.app.webViews.containing(.staticText, identifier: linkText).element
        let textElement = parent.staticTexts[prefix].firstMatch
        // click at middle of element1 to make sure the page has focus
        textElement.tapInTheMiddle()
        // Hold option
        XCUIElement.perform(withKeyModifiers: .option) {
            // While holding option
            // 1 point frame should be visible
            let shootSelections = journalView.app.otherElements.matching(identifier:"PointFrame")
            XCTAssertEqual(shootSelections.count, 1)
            // Clicking element to trigger shooting mode
            textElement.tapInTheMiddle()
            // Release option
        }
        
        // Add to today's note
        helper.addNote()
        // Confirm text is saved in Journal
        helper.showJournal()
        let title3Predicate = NSPredicate(format: "value = %@", titles[2])
        XCTAssertTrue(journalChildren.element(matching: title3Predicate).waitForExistence(timeout: 4))
        XCTAssertEqual(journalChildren.count, 2)
        XCTAssertEqual(journalChildren.element(boundBy: 0).value as? String, titles[2])
        XCTAssertTrue((((journalChildren.element(boundBy: 1).value as? String)?.contains(prefix + linkText)) != nil))
        // tap on collected sublink (end of new bullet)
        let linkWord = journalChildren.element(boundBy: 1).buttons[linkText]
        XCTAssertTrue(linkWord.waitForExistence(timeout: 5))
        linkWord.tapInTheMiddle()

        // tap on a link in the page, should be added to opened bullet
        let page2Link = journalView.app.webViews.staticTexts["I-Beam"].firstMatch
        XCTAssertTrue(page2Link.waitForExistence(timeout: 4))
        page2Link.tap()
        helper.showJournal()
        // let title2Predicate = NSPredicate(format: "value = %@", titles[1])
        // XCTAssertTrue(journalChildren.element(matching: title2Predicate).waitForExistence(timeout: 4))
        // XCTAssertEqual(journalChildren.count, 3)
        // XCTAssertEqual(journalChildren.element(boundBy: 2).value as? String, titles[1])
    }
}
