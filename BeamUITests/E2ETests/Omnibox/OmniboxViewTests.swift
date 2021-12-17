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
        XCTAssertTrue(omniboxView.button(OmniBoxLocators.Buttons.homeButton.accessibilityIdentifier).exists)
        let pivotButton = omniboxView.button(OmniBoxLocators.Buttons.openCardButton.accessibilityIdentifier)
        XCTAssertTrue(pivotButton.exists)
        XCTAssertEqual(pivotButton.title, "card")

        testRailPrint("When I click on pivot button")
        WebTestView().openDestinationCard()
        
        testRailPrint("Then journal view is opened")
        XCTAssertTrue(journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))

        testRailPrint("Then pivot button shows the number of tabs")
        let pivotWebButton = omniboxView.button(OmniBoxLocators.Buttons.openWebButton.accessibilityIdentifier)
        XCTAssertTrue(pivotWebButton.exists)
        XCTAssertEqual(pivotWebButton.title, "2")

        testRailPrint("When I open web view")
        CardTestView().navigateToWebView()
        
        testRailPrint("Then Webview is opened and Journal is closed")
        XCTAssertTrue(webView.getAnyTab().waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertFalse(journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).exists)
    }
}
