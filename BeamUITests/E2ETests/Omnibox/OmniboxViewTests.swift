//
//  OmniboxViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 09.08.2021.
//

import Foundation
import XCTest

class OmniboxViewTests: BaseTest {
    
    func testOmniBoxSearchField() {
        let textInput = "Hello World"
        let textEmpty = ""
        launchApp()
        
        let omniboxView = OmniBoxTestView()
        let omniboxSearchField = omniboxView.getOmniBoxSearchField()
        
        testRailPrint("Then Omnibox search field is focused on launched")
        XCTAssertTrue(omniboxView.inputHasFocus(omniboxSearchField))
        
        testRailPrint("When I type in Omnibox search field: \(textInput)")
        omniboxSearchField.typeText(textInput)
        
        testRailPrint("Then \(textInput) is correctly displayed in Omnibox search field")
        XCTAssertEqual(omniboxSearchField.value as? String, textInput)
        
        testRailPrint("When I delete: \(textInput)")
        omniboxView.typeKeyboardKey(.delete, 2)
        let startIndex = textInput.index(textInput.startIndex, offsetBy: 0)
        let endIndex = textInput.index(textInput.endIndex, offsetBy: -3)
        let partiallyDeletedSearchText = String(textInput[startIndex...endIndex])
        
        testRailPrint("Then \(textInput) is correctly displayed in Omnibox search field")
        XCTAssertEqual(omniboxSearchField.value as? String, partiallyDeletedSearchText)
        
        testRailPrint("When I delete all input: \(partiallyDeletedSearchText)")
        ShortcutsHelper().shortcutActionInvoke(action: .selectAll)
        omniboxView.typeKeyboardKey(.delete)
        
        testRailPrint("Then Omnibox search field is empty")
        XCTAssertEqual(omniboxSearchField.value as? String, textEmpty)
    }
    
    func testOmniboxPivotButtonClicking() {
        let journalView = launchApp()
        testRailPrint("Given I open 2 test pages")
        let omniboxView = OmniBoxTestView()
        BeamUITestsHelper(journalView.app).openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)
        BeamUITestsHelper(journalView.app).openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)
        
        testRailPrint("Then Webview is opened and browser tab bar is visible")
        let webView = WebTestView()
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
        journalView.createCardViaOmniboxSearch(noteATitle)
        journalView.createCardViaOmniboxSearch("Note B")
        journalView.createCardViaOmniboxSearch("Note C")

        let results = omniboxView.getAutocompleteResults()
        let noteResults = results.matching(omniboxHelper.autocompleteNotePredicate)
        // In all note
        testRailPrint("When I open omnibox in all notes")
        journalView.openAllCardsMenu()
        omniboxView.focusOmniBoxSearchField()
        testRailPrint("Then suggestions contains the correct actions")
        XCTAssertEqual(results.count, 5)
        XCTAssertEqual(results.element(boundBy: 2).label, noteATitle)
        XCTAssertEqual(results.element(boundBy: 3).label, OmniboxLocators.Labels.journal.accessibilityIdentifier)
        XCTAssertEqual(noteResults.count, 3)

        // In a note
        testRailPrint("When I open omnibox in a note view")
        journalView.openRecentCardByName(noteATitle)
        omniboxView.focusOmniBoxSearchField()
        testRailPrint("Then suggestions contains the correct actions")
        XCTAssertEqual(results.count, 6)
        XCTAssertEqual(results.element(boundBy: 0).label, noteATitle) // Note A moved up in the list of recents
        XCTAssertEqual(results.element(boundBy: 3).label, OmniboxLocators.Labels.journal.accessibilityIdentifier)
        XCTAssertEqual(results.element(boundBy: 4).label, OmniboxLocators.Labels.allNotes.accessibilityIdentifier)
        XCTAssertEqual(noteResults.count, 3)

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
        XCTAssertEqual(noteResults.count, 3)

        // In Web tab focus
        testRailPrint("When I open omnibox for a web tab")
        omniboxView.focusOmniBoxSearchField(forCurrenTab: true)
        testRailPrint("Then suggestions contains the correct actions")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.element(boundBy: 0).label, OmniboxLocators.Labels.copyTab.accessibilityIdentifier)
        XCTAssertEqual(results.element(boundBy: 1).label, OmniboxLocators.Labels.collectTab.accessibilityIdentifier)
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
        XCTAssertEqual(noteResults.count, 3)
    }
}
