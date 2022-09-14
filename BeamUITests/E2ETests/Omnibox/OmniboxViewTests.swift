//
//  OmniboxViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 09.08.2021.
//

import Foundation
import XCTest
import BeamCore

class OmniboxViewTests: BaseTest {
    
    let omniboxView = OmniBoxTestView()
    let noteView = NoteTestView()
    let journalView = JournalTestView()
    var stopMockServer = false
    
    override func tearDown() {
        if stopMockServer {
            uiMenu.invoke(.stopMockHttpServer)
        }
        super.tearDown()
    }
    
    func testOmniBoxSearchField() {
        testrailId("C742")
        let textInput = "Hello World"
        let omniboxSearchField = omniboxView.getOmniBoxSearchField()

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
        
        testrailId("C565")
        step("When I delete all input: \(partiallyDeletedSearchText)") {
            shortcutHelper.shortcutActionInvoke(action: .selectAll)
            omniboxView.typeKeyboardKey(.delete)
        }
        
        step("Then Omnibox search field is empty") {
            XCTAssertEqual(omniboxView.getSearchFieldValue(), emptyString)
        }
        
    }
    
    func testOmniboxPivotButtonClicking() {
        
        step("Given I open 2 test pages"){
            uiMenu.invoke(.loadUITestPage1)
                .invoke(.loadUITestPage2)
        }

        step("Then Webview is opened and browser tab bar is visible"){
            XCTAssertTrue(webView.getAnyTab().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertEqual(omniboxView.getAutocompleteResults().count, 0)
            XCTAssertTrue(omniboxView.button(ToolbarLocators.Buttons.homeButton.accessibilityIdentifier).exists)
            let pivotButton = omniboxView.button(ToolbarLocators.Buttons.openNoteButton.accessibilityIdentifier)
            XCTAssertTrue(pivotButton.exists)
            XCTAssertEqual(pivotButton.title, "note")
        }
        
        testrailId("C1095")
        step("When I click on pivot button"){
            webView.openDestinationNote()
        }
        
        step("Then journal view is opened"){
            XCTAssertTrue(journalView.getScrollViewElement().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

        testrailId("C1096")
        step("Then pivot button shows the number of tabs"){
            let pivotWebButton = omniboxView.button(ToolbarLocators.Buttons.openWebButton.accessibilityIdentifier)
            XCTAssertTrue(pivotWebButton.exists)
            XCTAssertEqual(pivotWebButton.title, "2")
        }

        step("When I open web view"){
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step("Then Webview is opened and Journal is closed"){
            XCTAssertTrue(webView.getAnyTab().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertFalse(journalView.getScrollViewElement().exists)
        }
    }

    func testOmniboxDropdownItems() {
        testrailId("C1097")
        let noteATitle = "Test1"
        let noteBTitle = "Test2"

        step("Given I have at least 4 notes"){
            deleteAllNotes() // delete onboarding notes
            //Open is required to make it appear in autocomplete
            uiMenu.invoke(.createAndOpenNote)
                .invoke(.createAndOpenNote)
                .invoke(.createAndOpenNote)
        }
        let results = omniboxView.getAutocompleteResults()
        let noteResults = omniboxView.getNoteAutocompleteElementQuery()

        // In all note
        step("When I open omnibox in all notes"){
            journalView.openAllNotesMenu()
        }

        testrailId("C820")
        step("Then suggestions contains the correct actions"){
            XCTAssertTrue(AllNotesTestView()
                .clickOmniboxIcon()
                .getOmniBoxSearchField().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertEqual(results.count, 5)
            XCTAssertEqual(results.element(boundBy: 2).getStringValue(), noteATitle) // Note A is last
            XCTAssertEqual(results.element(boundBy: 3).getStringValue(), OmniboxLocators.Labels.journal.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 4).label, OmniboxLocators.Labels.createNote.accessibilityIdentifier)
            XCTAssertEqual(noteResults.count, 3)
        }

        // In a note
        step("When I open omnibox in a note view"){
            openNoteByTitle(noteATitle)
            openNoteByTitle(noteBTitle)
            omniboxView.focusOmniBoxSearchField()
        }

        step("Then suggestions contains the correct actions"){
            XCTAssertEqual(results.count, 5)
            XCTAssertEqual(results.element(boundBy: 0).getStringValue(), noteATitle) // Note A moved up in the list of recents
            XCTAssertNotEqual(results.element(boundBy: 1).getStringValue(), noteBTitle) // Note B is not suggested because we're already on it.
            XCTAssertEqual(results.element(boundBy: 2).getStringValue(), OmniboxLocators.Labels.journal.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 3).getStringValue(), OmniboxLocators.Labels.allNotes.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 4).label, OmniboxLocators.Labels.createNote.accessibilityIdentifier)
            XCTAssertEqual(noteResults.count, 2)
            openNoteByTitle(noteATitle)
        }

        // In Web
        step("When I open omnibox in web mode"){
            uiMenu.invoke(.loadUITestPage1)
            omniboxView.focusOmniBoxSearchField()
        }

        step("Then suggestions contains the correct actions"){
            XCTAssertEqual(results.count, 7)
            XCTAssertEqual(results.element(boundBy: 0).getStringValue(), noteATitle)
            XCTAssertEqual(results.element(boundBy: 3).getStringValue(), OmniboxLocators.Labels.journal.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 4).getStringValue(), OmniboxLocators.Labels.allNotes.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 5).getStringValue(), OmniboxLocators.Labels.switchToNotes.accessibilityIdentifier)
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
            shortcutHelper.shortcutActionInvoke(action: .showJournal)
            journalView.waitForJournalViewToLoad()
            omniboxView.focusOmniBoxSearchField()
        }

        step("Then suggestions contains the correct actions"){
            XCTAssertEqual(results.count, 6)
            XCTAssertEqual(noteResults.count, 3)
        }
    }
    
    func testOmniboxTextSelectionAndEditing() {
        testrailId("C1098")
        let initialSearch = mockPage.getMockPageUrl(.mainView)
        let expectedInitialSearchURLinTab = "http://localhost:\(EnvironmentVariables.MockHttpServer.port)/"
        let expectedTabTitle = "Mock HTTP Server"
        
        let editedSourceToSearch = "menu.form.lvh.me"
        let expectedEditedSourceToSearchURL = "http://menu.form.lvh.me:\(EnvironmentVariables.MockHttpServer.port)/"
        let editedSourceToSearchInTab = "menu.form.lvh.me:\(EnvironmentVariables.MockHttpServer.port)/"
        
        let replacedSourceToSearch = "http://nestediframe.form.lvh.me:\(EnvironmentVariables.MockHttpServer.port)/"
        let replacedSourceToSearchInTab = "nestediframe.form.lvh.me:\(EnvironmentVariables.MockHttpServer.port)/"
        let expectedReplacedSourceToSearchURL = "http://nestediframe.form.lvh.me:\(EnvironmentVariables.MockHttpServer.port)/"
        
        uiMenu.invoke(.startMockHttpServer)
        stopMockServer = true
        
        step("GIVEN I open \(initialSearch)"){
            mockPage.openMockPage(.mainView)
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
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .selectOnLeft, numberOfTimes: 9)
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
        testrailId("C745")
        let noteATitle = "Test1"

        step("Given I have at least 1 note"){
            uiMenu.invoke(.createAndOpenNote)
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
            omniboxView.enterCreateNoteMode()
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

        let secondNoteTitle = "Tes"
        step("When I enter create note mode and type a new note name"){
            omniboxView.enterCreateNoteMode()
            omniboxView.typeInOmnibox(secondNoteTitle)
        }

        step("Then create action is selected and notes are suggested"){
            XCTAssertEqual(results.count, 2)
            XCTAssertEqual(results.element(boundBy: 0).label, OmniboxLocators.Labels.createNotePrefix.accessibilityIdentifier)
            XCTAssertEqual(results.element(boundBy: 1).getStringValue(), noteATitle)
            XCTAssertEqual(omniboxView.getCreateNoteAutocompleteElementQuery().count, 1)
        }
        
        step("When I press enter"){
            omniboxView.typeKeyboardKey(.enter)
        }
        
        step("Then the note is created"){
            XCTAssertTrue(noteView.waitForNoteViewToLoad())
            XCTAssertEqual(noteView.getNoteTitle(), secondNoteTitle)
        }
        
    }
    
    // BE-2546
    func testOmniboxIsDismissedWhenSummonedTwice() {
        testrailId("C1099")
        step("When I open omnibox with shortcut") {
            omniboxView.focusOmniBoxSearchField()
        }
        
        step("Then omnibox menu is displayed") {
            XCTAssertTrue(omniboxView.doesOmniboxCreateNoteExist())
            XCTAssertTrue(omniboxView.doesOmniboxAllNotesExist())
            XCTAssertTrue(omniboxView.isOmniboxFocused())
        }
        
        step("When I reinvoke omnibox with shortcut") {
            omniboxView.focusOmniBoxSearchField()
        }
        
        step("Then omnibox menu is closed") {
            XCTAssertFalse(omniboxView.doesOmniboxCreateNoteExist())
            XCTAssertFalse(omniboxView.doesOmniboxAllNotesExist())
            XCTAssertFalse(omniboxView.isOmniboxFocused())
        }
    }
    
}
