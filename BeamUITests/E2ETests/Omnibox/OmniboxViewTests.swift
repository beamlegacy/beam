//
//  OmniboxViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 09.08.2021.
//

import Foundation
import XCTest

class OmniboxViewTests: BaseTest {
    
    let webView = WebTestView()
    let omniboxView = OmniBoxTestView()
    var stopMockServer = false
    
    override func tearDown() {
        if stopMockServer {
            UITestsMenuBar().stopMockHTTPServer()
        }
        super.tearDown()
    }
    
    func testOmniBoxSearchField() {
        let textInput = "Hello World"
        let textEmpty = ""

        let omniboxView = OmniBoxTestView()
        let omniboxSearchField = omniboxView.getOmniBoxSearchField()
        
        step("Given I launch the app") {
            launchApp()
        }

        step("Then Omnibox search field is focused on launched") {
            XCTAssertTrue(omniboxView.inputHasFocus(omniboxSearchField))
        }
        
        step("When I type in Omnibox search field: \(textInput)") {
            omniboxSearchField.typeText(textInput)
        }
        
        step("Then \(textInput) is correctly displayed in Omnibox search field") {
            XCTAssertEqual(omniboxSearchField.value as? String, textInput)
        }
        
        step("When I delete: \(textInput)") {
            omniboxView.typeKeyboardKey(.delete, 2)
        }
        
        let startIndex = textInput.index(textInput.startIndex, offsetBy: 0)
        let endIndex = textInput.index(textInput.endIndex, offsetBy: -3)
        let partiallyDeletedSearchText = String(textInput[startIndex...endIndex])

        step("Then \(textInput) is correctly displayed in Omnibox search field") {
            XCTAssertEqual(omniboxSearchField.value as? String, partiallyDeletedSearchText)
        }
        
        step("When I delete all input: \(partiallyDeletedSearchText)") {
            ShortcutsHelper().shortcutActionInvoke(action: .selectAll)
            omniboxView.typeKeyboardKey(.delete)
        }
        
        step("Then Omnibox search field is empty") {
            XCTAssertEqual(omniboxSearchField.value as? String, textEmpty)
        }
        
    }
    
    func testOmniboxPivotButtonClicking() {
        let journalView = launchApp()
        testRailPrint("Given I open 2 test pages")
        BeamUITestsHelper(journalView.app).openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)
        BeamUITestsHelper(journalView.app).openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)
        
        testRailPrint("Then Webview is opened and browser tab bar is visible")
        XCTAssertTrue(webView.getAnyTab().waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertEqual(omniboxView.getAutocompleteResults().count, 0)
        XCTAssertTrue(omniboxView.button(ToolbarLocators.Buttons.homeButton.accessibilityIdentifier).exists)
        let pivotButton = omniboxView.button(ToolbarLocators.Buttons.openCardButton.accessibilityIdentifier)
        XCTAssertTrue(pivotButton.exists)
        XCTAssertEqual(pivotButton.title, "note")

        testRailPrint("When I click on pivot button")
        WebTestView().openDestinationCard()
        
        testRailPrint("Then journal view is opened")
        XCTAssertTrue(journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))

        testRailPrint("Then pivot button shows the number of tabs")
        let pivotWebButton = omniboxView.button(ToolbarLocators.Buttons.openWebButton.accessibilityIdentifier)
        XCTAssertTrue(pivotWebButton.exists)
        XCTAssertEqual(pivotWebButton.title, "2")

        testRailPrint("When I open web view")
        CardTestView().navigateToWebView()
        
        testRailPrint("Then Webview is opened and Journal is closed")
        XCTAssertTrue(webView.getAnyTab().waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertFalse(journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).exists)
    }

    func testOmniboxDefaultActions() {
        let omniboxView = OmniBoxTestView()
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        let omniboxHelper = OmniBoxUITestsHelper(OmniBoxTestView().app)

        testRailPrint("Given I have at least 4 notes")
        let noteATitle = "Note A"
        let noteBTitle = "Note B"
        journalView.createCardViaOmniboxSearch(noteATitle)
        journalView.createCardViaOmniboxSearch(noteBTitle)
        journalView.createCardViaOmniboxSearch("Note C")

        let results = omniboxView.getAutocompleteResults()
        let noteResults = results.matching(omniboxHelper.autocompleteNotePredicate)
        // In all note
        testRailPrint("When I open omnibox in all notes")
        journalView.openAllCardsMenu()
        omniboxView.focusOmniBoxSearchField()
        testRailPrint("Then suggestions contains the correct actions")
        XCTAssertEqual(results.count, 5)
        XCTAssertEqual(results.element(boundBy: 2).label, noteATitle) // Note A is last
        XCTAssertEqual(results.element(boundBy: 3).label, OmniboxLocators.Labels.journal.accessibilityIdentifier)
        XCTAssertEqual(results.element(boundBy: 4).label, OmniboxLocators.Labels.createNote.accessibilityIdentifier)
        XCTAssertEqual(noteResults.count, 3)

        // In a note
        testRailPrint("When I open omnibox in a note view")
        journalView.openRecentCardByName(noteATitle)
        journalView.openRecentCardByName(noteBTitle)
        omniboxView.focusOmniBoxSearchField()
        testRailPrint("Then suggestions contains the correct actions")
        XCTAssertEqual(results.count, 6)
        XCTAssertEqual(results.element(boundBy: 0).label, noteATitle) // Note A moved up in the list of recents
        XCTAssertNotEqual(results.element(boundBy: 1).label, noteBTitle) // Note B is not suggested because we're already on it.
        XCTAssertNotEqual(results.element(boundBy: 2).label, noteBTitle) // Note B is not suggested because we're already on it.
        XCTAssertEqual(results.element(boundBy: 3).label, OmniboxLocators.Labels.journal.accessibilityIdentifier)
        XCTAssertEqual(results.element(boundBy: 4).label, OmniboxLocators.Labels.allNotes.accessibilityIdentifier)
        XCTAssertEqual(results.element(boundBy: 5).label, OmniboxLocators.Labels.createNote.accessibilityIdentifier)
        XCTAssertEqual(noteResults.count, 3)
        journalView.openRecentCardByName(noteATitle)

        // In Web
        testRailPrint("When I open omnibox in web mode")
        helper.openTestPage(page: .page1)
        omniboxView.focusOmniBoxSearchField()
        testRailPrint("Then suggestions contains the correct actions")
        XCTAssertEqual(results.count, 7)
        XCTAssertEqual(results.element(boundBy: 0).label, noteATitle)
        XCTAssertEqual(results.element(boundBy: 3).label, OmniboxLocators.Labels.journal.accessibilityIdentifier)
        XCTAssertEqual(results.element(boundBy: 4).label, OmniboxLocators.Labels.allNotes.accessibilityIdentifier)
        XCTAssertEqual(results.element(boundBy: 5).label, OmniboxLocators.Labels.switchToNotes.accessibilityIdentifier)
        XCTAssertEqual(results.element(boundBy: 6).label, OmniboxLocators.Labels.createNote.accessibilityIdentifier)
        XCTAssertEqual(noteResults.count, 3)

        // In Web tab focus
        testRailPrint("When I open omnibox for a web tab")
        omniboxView.focusOmniBoxSearchField(forCurrenTab: true)
        testRailPrint("Then suggestions contains the correct actions")
        XCTAssertEqual(results.count, 0)
        XCTAssertEqual(noteResults.count, 0)

        // In journal
        testRailPrint("When I open omnibox for the journal")
        helper.showJournal()
        omniboxView.focusOmniBoxSearchField()
        testRailPrint("Then suggestions contains the correct actions")
        XCTAssertEqual(results.count, 6)
        XCTAssertEqual(results.element(boundBy: 0).label, noteATitle)
        XCTAssertEqual(results.element(boundBy: 3).label, OmniboxLocators.Labels.allNotes.accessibilityIdentifier)
        XCTAssertEqual(results.element(boundBy: 4).label, OmniboxLocators.Labels.switchToWeb.accessibilityIdentifier)
        XCTAssertEqual(results.element(boundBy: 5).label, OmniboxLocators.Labels.createNote.accessibilityIdentifier)
        XCTAssertEqual(noteResults.count, 3)
    }
    
    func testOmniboxTextSelectionAndEditing() throws {
        let initialSearch = "http://localhost:8080/"
        let expectedInitialSearchURLinTab = "http://localhost:8080/"
        let expectedTabTitle = "Mock Form Server"
        
        let editedSourceToSearch = "menu.form.lvh.me"
        let expectedEditedSourceToSearchURL = "http://menu.form.lvh.me:8080/"
        let editedSourceToSearchInTab = "menu.form.lvh.me:8080/"
        
        let replacedSourceToSearch = "http://nestediframe.form.lvh.me:8080/"
        let replacedSourceToSearchInTab = "nestediframe.form.lvh.me:8080/"
        let expectedReplacedSourceToSearchURL = "http://nestediframe.form.lvh.me:8080/"
        
        launchApp()
        UITestsMenuBar().startMockHTTPServer()
        stopMockServer = true
        
        testRailPrint("GIVEN I open \(initialSearch)")
        omniboxView.typeInOmnibox(initialSearch)
        omniboxView.typeKeyboardKey(.enter)
        
        testRailPrint("THEN I see \(expectedTabTitle) Tab title")
        XCTAssertTrue(webView.waitForTabTitleToEqual(index: 0, expectedString: expectedTabTitle), "Timeout waiting \(webView.getBrowserTabTitleValueByIndex(index: 0)) to equal \(expectedTabTitle)")
        
        testRailPrint("THEN I see \(expectedInitialSearchURLinTab) URL in search field")
        XCTAssertTrue(webView
                        .activateSearchFieldFromTab(index: 0)
                        .waitForSearchFieldValueToEqual(expectedValue: expectedInitialSearchURLinTab),
                      "Timeout waiting \(webView.getTabUrlAtIndex(index: 0)) to equal \(expectedInitialSearchURLinTab)")
        
        testRailPrint("WHEN I edit the host name with \(editedSourceToSearch)")
        webView.activateSearchFieldFromTab(index: 0)
        omniboxView.typeKeyboardKey(.rightArrow)
        omniboxView.typeKeyboardKey(.leftArrow, 6)
        ShortcutsHelper().shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: 9)
        omniboxView.typeInOmnibox(editedSourceToSearch)
        
        testRailPrint("THEN I see \(expectedEditedSourceToSearchURL) as a search value")
        XCTAssertTrue(omniboxView.waitForSearchFieldValueToEqual(expectedValue: expectedEditedSourceToSearchURL), "Timeout waiting \(webView.getTabUrlAtIndex(index: 0)) to equal \(expectedEditedSourceToSearchURL)")
        
        testRailPrint("THEN I see \(editedSourceToSearchInTab) URL in tab on search")
        omniboxView.typeKeyboardKey(.enter)
        XCTAssertTrue(webView.waitForTabUrlAtIndexToEqual(index: 0, expectedString: editedSourceToSearchInTab), "Timeout waiting \(webView.getTabUrlAtIndex(index: 0)) to equal \(editedSourceToSearchInTab)")
        
        testRailPrint("THEN I see successfully clear the search field")
        webView.activateSearchFieldFromTab(index: 0).typeKeyboardKey(.delete)
            //.clearOmniboxViaXbutton() Currently is blocked due to clear button is not hittable
        XCTAssertTrue(omniboxView.waitForSearchFieldValueToEqual(expectedValue: emptyString))
        
        testRailPrint("WHEN I replace the host with \(replacedSourceToSearch)")
        omniboxView.typeInOmnibox(replacedSourceToSearch)
        
        testRailPrint("THEN I see \(expectedReplacedSourceToSearchURL) as a search value")
        XCTAssertTrue(omniboxView.waitForSearchFieldValueToEqual(expectedValue: expectedReplacedSourceToSearchURL), "Timeout waiting \(webView.getTabUrlAtIndex(index: 0)) to equal \(expectedReplacedSourceToSearchURL)")
        
        testRailPrint("THEN I see \(replacedSourceToSearchInTab) URL in tab on search")
        omniboxView.typeKeyboardKey(.enter)
        XCTAssertTrue(webView.waitForTabUrlAtIndexToEqual(index: 0, expectedString: replacedSourceToSearchInTab), "Timeout waiting \(webView.getTabUrlAtIndex(index: 0)) to equal \(replacedSourceToSearchInTab)")
    }
    
    func testOmniboxCreateNoteMode() {
        let omniboxView = OmniBoxTestView()
        let journalView = launchApp()
        let omniboxHelper = OmniBoxUITestsHelper(OmniBoxTestView().app)

        testRailPrint("Given I have at least 1 note")
        let noteATitle = "Note A"
        journalView.createCardViaOmniboxSearch(noteATitle)

        let results = omniboxView.getAutocompleteResults()
        testRailPrint("When I open omnibox")
        omniboxView.focusOmniBoxSearchField()
        testRailPrint("Then suggestions contains the correct note and actions")
        let defaultSuggestionsCount = results.count
        XCTAssertGreaterThan(defaultSuggestionsCount, 0)
        XCTAssertEqual(results.element(boundBy: results.count - 1).label, OmniboxLocators.Labels.createNote.accessibilityIdentifier)

        testRailPrint("When I enter create note mode")
        omniboxView.enterCreateCardMode()
        testRailPrint("Then no suggestion is shown")
        XCTAssertEqual(results.count, 0)

        testRailPrint("When I press escape")
        omniboxView.typeKeyboardKey(.escape)
        testRailPrint("Then I leave create note mode")
        XCTAssertEqual(results.count, defaultSuggestionsCount)

        let secondNoteTitle = "Not"
        testRailPrint("When I enter create note mode and type a new note name")
        omniboxView.enterCreateCardMode()
        omniboxView.typeInOmnibox(secondNoteTitle)
        testRailPrint("Then create action is selected and notes are suggested")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.element(boundBy: 0).label, OmniboxLocators.Labels.createNotePrefix.accessibilityIdentifier)
        XCTAssertEqual(results.element(boundBy: 1).label, noteATitle)
        XCTAssertEqual(results.matching(omniboxHelper.autocompleteCreateCardPredicate).count, 1)

        testRailPrint("When I press enter")
        omniboxView.typeKeyboardKey(.enter)
        testRailPrint("Then the note is created")
        let cardView = CardTestView()
        XCTAssertTrue(cardView.waitForCardViewToLoad())
        XCTAssertTrue(cardView.textField(secondNoteTitle).waitForExistence(timeout: implicitWaitTimeout))
    }
    
}
