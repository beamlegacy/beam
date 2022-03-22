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
    let cardView = CardTestView()
    var stopMockServer = false
    
    override func tearDown() {
        if stopMockServer {
            UITestsMenuBar().stopMockHTTPServer()
        }
        super.tearDown()
    }
    
    func testOmniBoxSearchField() {
        let textInput = "Hello World"
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
            XCTAssertEqual(omniboxView.getSearchFieldValue(), textInput)
        }
        
        step("When I delete: \(textInput)") {
            omniboxView.typeKeyboardKey(.delete, 2)
        }
        
        let startIndex = textInput.index(textInput.startIndex, offsetBy: 0)
        let endIndex = textInput.index(textInput.endIndex, offsetBy: -3)
        let partiallyDeletedSearchText = String(textInput[startIndex...endIndex])

        step("Then \(textInput) is correctly displayed in Omnibox search field") {
            XCTAssertEqual(omniboxView.getSearchFieldValue(), partiallyDeletedSearchText)
        }
        
        step("When I delete all input: \(partiallyDeletedSearchText)") {
            ShortcutsHelper().shortcutActionInvoke(action: .selectAll)
            omniboxView.typeKeyboardKey(.delete)
        }
        
        step("Then Omnibox search field is empty") {
            XCTAssertEqual(omniboxView.getSearchFieldValue(), emptyString)
        }
        
    }
    
    func testOmniboxPivotButtonClicking() {
        let journalView = launchApp()
        
        step("Given I open 2 test pages"){
            BeamUITestsHelper(journalView.app).openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)
            BeamUITestsHelper(journalView.app).openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)
        }

        step("Then Webview is opened and browser tab bar is visible"){
            XCTAssertTrue(webView.getAnyTab().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertEqual(omniboxView.getAutocompleteResults().count, 0)
            XCTAssertTrue(omniboxView.button(ToolbarLocators.Buttons.homeButton.accessibilityIdentifier).exists)
            let pivotButton = omniboxView.button(ToolbarLocators.Buttons.openCardButton.accessibilityIdentifier)
            XCTAssertTrue(pivotButton.exists)
            XCTAssertEqual(pivotButton.title, "note")
        }

        step("When I click on pivot button"){
            WebTestView().openDestinationCard()
        }
        
        step("Then journal view is opened"){
            XCTAssertTrue(journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

        step("Then pivot button shows the number of tabs"){
            let pivotWebButton = omniboxView.button(ToolbarLocators.Buttons.openWebButton.accessibilityIdentifier)
            XCTAssertTrue(pivotWebButton.exists)
            XCTAssertEqual(pivotWebButton.title, "2")
        }

        step("When I open web view"){
            CardTestView().navigateToWebView()
        }
        
        step("Then Webview is opened and Journal is closed"){
            XCTAssertTrue(webView.getAnyTab().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertFalse(journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).exists)
        }

    }

    func testOmniboxDefaultActions() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        let omniboxHelper = OmniBoxUITestsHelper(OmniBoxTestView().app)
        let noteATitle = "Note A"
        let noteBTitle = "Note B"

        step("Given I have at least 4 notes"){
            journalView.createCardViaOmniboxSearch(noteATitle)
            journalView.createCardViaOmniboxSearch(noteBTitle)
            journalView.createCardViaOmniboxSearch("Note C")
        }
        let results = omniboxView.getAutocompleteResults()
        let noteResults = results.matching(omniboxHelper.autocompleteNotePredicate)

        // In all note
        step("When I open omnibox in all notes"){
            journalView.openAllCardsMenu()
            omniboxView.focusOmniBoxSearchField()
        }

        step("Then suggestions contains the correct actions"){
            XCTAssertEqual(results.count, 5)
            XCTAssertEqual(results.element(boundBy: 2).label, noteATitle) // Note A is last
            XCTAssertEqual(results.element(boundBy: 3).label, OmniboxLocators.Labels.journal.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 4).label, OmniboxLocators.Labels.createNote.accessibilityIdentifier)
            XCTAssertEqual(noteResults.count, 3)
        }


        // In a note
        step("When I open omnibox in a note view"){
            journalView.openRecentCardByName(noteATitle)
            journalView.openRecentCardByName(noteBTitle)
            omniboxView.focusOmniBoxSearchField()
        }

        step("Then suggestions contains the correct actions"){
            XCTAssertEqual(results.count, 6)
            XCTAssertEqual(results.element(boundBy: 0).label, noteATitle) // Note A moved up in the list of recents
            XCTAssertNotEqual(results.element(boundBy: 1).label, noteBTitle) // Note B is not suggested because we're already on it.
            XCTAssertNotEqual(results.element(boundBy: 2).label, noteBTitle) // Note B is not suggested because we're already on it.
            XCTAssertEqual(results.element(boundBy: 3).label, OmniboxLocators.Labels.journal.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 4).label, OmniboxLocators.Labels.allNotes.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 5).label, OmniboxLocators.Labels.createNote.accessibilityIdentifier)
            XCTAssertEqual(noteResults.count, 3)
            journalView.openRecentCardByName(noteATitle)
        }

        // In Web
        step("When I open omnibox in web mode"){
            helper.openTestPage(page: .page1)
            omniboxView.focusOmniBoxSearchField()
        }

        step("Then suggestions contains the correct actions"){
            XCTAssertEqual(results.count, 7)
            XCTAssertEqual(results.element(boundBy: 0).label, noteATitle)
            XCTAssertEqual(results.element(boundBy: 3).label, OmniboxLocators.Labels.journal.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 4).label, OmniboxLocators.Labels.allNotes.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 5).label, OmniboxLocators.Labels.switchToNotes.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 6).label, OmniboxLocators.Labels.createNote.accessibilityIdentifier)
            XCTAssertEqual(noteResults.count, 3)
        }

        // In Web tab focus
        step("When I open omnibox for a web tab"){
            omniboxView.focusOmniBoxSearchField(forCurrenTab: true)
        }
        
        step("Then suggestions contains the correct actions"){
            XCTAssertEqual(results.count, 0)
            XCTAssertEqual(noteResults.count, 0)
        }

        // In journal
        step("When I open omnibox for the journal"){
            helper.showJournal()
            journalView.waitForJournalViewToLoad()
            omniboxView.focusOmniBoxSearchField()
        }

        step("Then suggestions contains the correct actions"){
            XCTAssertEqual(results.count, 6)
            XCTAssertEqual(noteResults.count, 3)
        }
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
        
        step("GIVEN I open \(initialSearch)"){
            omniboxView.typeInOmnibox(initialSearch)
            omniboxView.typeKeyboardKey(.enter)
        }

        step("THEN I see \(expectedTabTitle) Tab title"){
            XCTAssertTrue(webView.waitForTabTitleToEqual(index: 0, expectedString: expectedTabTitle), "Timeout waiting \(webView.getBrowserTabTitleValueByIndex(index: 0)) to equal \(expectedTabTitle)")
        }
        

        step("THEN I see \(expectedInitialSearchURLinTab) URL in search field"){
            XCTAssertTrue(webView
                            .activateSearchFieldFromTab(index: 0)
                            .waitForSearchFieldValueToEqual(expectedValue: expectedInitialSearchURLinTab),
                          "Timeout waiting \(webView.getTabUrlAtIndex(index: 0)) to equal \(expectedInitialSearchURLinTab)")
        }

        step("WHEN I edit the host name with \(editedSourceToSearch)"){
            webView.activateSearchFieldFromTab(index: 0)
            omniboxView.typeKeyboardKey(.rightArrow)
            omniboxView.typeKeyboardKey(.leftArrow, 6)
            ShortcutsHelper().shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: 9)
            omniboxView.typeInOmnibox(editedSourceToSearch)
        }

        step("THEN I see \(expectedEditedSourceToSearchURL) as a search value"){
            XCTAssertTrue(omniboxView.waitForSearchFieldValueToEqual(expectedValue: expectedEditedSourceToSearchURL), "Timeout waiting \(webView.getTabUrlAtIndex(index: 0)) to equal \(expectedEditedSourceToSearchURL)")
        }

        step("AND I see \(editedSourceToSearchInTab) URL in tab on search"){
            omniboxView.typeKeyboardKey(.enter)
            XCTAssertTrue(webView.waitForTabUrlAtIndexToEqual(index: 0, expectedString: editedSourceToSearchInTab), "Timeout waiting \(webView.getTabUrlAtIndex(index: 0)) to equal \(editedSourceToSearchInTab)")
        }

        step("THEN I see successfully clear the search field"){
            webView.activateSearchFieldFromTab(index: 0).typeKeyboardKey(.delete)
            XCTAssertTrue(omniboxView.waitForSearchFieldValueToEqual(expectedValue: emptyString))
        }
        
        step("WHEN I replace the host with \(replacedSourceToSearch)"){
            omniboxView.typeInOmnibox(replacedSourceToSearch)

        }
        
        step("THEN I see \(expectedReplacedSourceToSearchURL) as a search value"){
            XCTAssertTrue(omniboxView.waitForSearchFieldValueToEqual(expectedValue: expectedReplacedSourceToSearchURL), "Timeout waiting \(webView.getTabUrlAtIndex(index: 0)) to equal \(expectedReplacedSourceToSearchURL)")
        }
        
        step("THEN I see \(replacedSourceToSearchInTab) URL in tab on search"){
            omniboxView.typeKeyboardKey(.enter)
            XCTAssertTrue(webView.waitForTabUrlAtIndexToEqual(index: 0, expectedString: replacedSourceToSearchInTab), "Timeout waiting \(webView.getTabUrlAtIndex(index: 0)) to equal \(replacedSourceToSearchInTab)")
        }

    }
    
    func testOmniboxCreateNoteMode() {
        let journalView = launchApp()
        let omniboxHelper = OmniBoxUITestsHelper(OmniBoxTestView().app)
        let noteATitle = "Note A"

        step("Given I have at least 1 note"){
            journalView.createCardViaOmniboxSearch(noteATitle)
        }
        
        let results = omniboxView.getAutocompleteResults()
        
        step("When I open omnibox"){
            omniboxView.focusOmniBoxSearchField()
        }
        let defaultSuggestionsCount = results.count

        step("Then suggestions contains the correct note and actions"){
            XCTAssertGreaterThan(defaultSuggestionsCount, 0)
            XCTAssertEqual(results.element(boundBy: results.count - 1).label, OmniboxLocators.Labels.createNote.accessibilityIdentifier)
        }
        
        step("When I enter create note mode"){
            omniboxView.enterCreateCardMode()
        }
        
        step("Then no suggestion is shown"){
            XCTAssertEqual(results.count, 0)
        }

        step("When I press escape"){
            omniboxView.typeKeyboardKey(.escape)
        }
        
        step("Then I leave create note mode"){
            XCTAssertEqual(results.count, defaultSuggestionsCount)
        }

        let secondNoteTitle = "Not"
        step("When I enter create note mode and type a new note name"){
            omniboxView.enterCreateCardMode()
            omniboxView.typeInOmnibox(secondNoteTitle)
        }

        step("Then create action is selected and notes are suggested"){
            XCTAssertEqual(results.count, 2)
            XCTAssertEqual(results.element(boundBy: 0).label, OmniboxLocators.Labels.createNotePrefix.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 1).label, noteATitle)
            XCTAssertEqual(results.matching(omniboxHelper.autocompleteCreateCardPredicate).count, 1)
        }
        
        step("When I press enter"){
            omniboxView.typeKeyboardKey(.enter)
        }
        
        step("Then the note is created"){
            XCTAssertTrue(cardView.waitForCardViewToLoad())
            XCTAssertTrue(cardView.textField(secondNoteTitle).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
        
    }
    
}
