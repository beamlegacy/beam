//
//  OmnibarViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 09.08.2021.
//

import Foundation
import XCTest

class OmnibarViewTests: BaseTest {
    
    func testOmniBarSearchField() {
        let textInput = "Hello World"
        let textEmpty = ""
        launchApp()
        
        let omnibarView = OmniBarTestView()
        let omnibarSearchField = omnibarView.searchField(OmniBarLocators.SearchFields.omniSearchField.accessibilityIdentifier)
        
        testRailPrint("Then Omnibar search field is focused on launched")
        XCTAssertTrue(omnibarView.inputHasFocus(omnibarSearchField))
        
        testRailPrint("When I type in Omnibar search field: \(textInput)")
        omnibarSearchField.typeText(textInput)
        
        testRailPrint("Then \(textInput) is correctly displayed in Omnibar search field")
        XCTAssertEqual(omnibarSearchField.value as? String, textInput)
        
        testRailPrint("When I delete: \(textInput)")
        omnibarView.typeKeyboardKey(.delete, 2)
        let startIndex = textInput.index(textInput.startIndex, offsetBy: 0)
        let endIndex = textInput.index(textInput.endIndex, offsetBy: -3)
        let partiallyDeletedSearchText = String(textInput[startIndex...endIndex])
        
        testRailPrint("Then \(textInput) is correctly displayed in Omnibar search field")
        XCTAssertEqual(omnibarSearchField.value as? String, partiallyDeletedSearchText)
        
        testRailPrint("When I delete all input: \(partiallyDeletedSearchText)")
        ShortcutsHelper().shortcutActionInvoke(action: .selectAll)
        omnibarView.typeKeyboardKey(.delete)
        
        testRailPrint("Then Omnibar search field is empty")
        XCTAssertEqual(omnibarSearchField.value as? String, textEmpty)
    }
    
    func testOmnibarPivotButtonClicking() {
        let journalView = launchApp()
        
        testRailPrint("Given I open test page")
        let omnibarView = OmniBarTestView()
        BeamUITestsHelper(journalView.app).openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)
        
        testRailPrint("Then Webview is opened and Omnibar has additional buttons")
        XCTAssertTrue(journalView.group(WebViewLocators.Images.browserTabBar.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertEqual(omnibarView.getAutocompleteResults().count, 0)
        XCTAssertTrue(omnibarView.button(OmniBarLocators.Buttons.homeButton.accessibilityIdentifier).exists)
        XCTAssertTrue(omnibarView.button(OmniBarLocators.Buttons.refreshButton.accessibilityIdentifier).exists)
        XCTAssertTrue(omnibarView.button(OmniBarLocators.Buttons.openCardButton.accessibilityIdentifier).exists)

        testRailPrint("When I click on pivot button")
        WebTestView().openDestinationCard()
        
        testRailPrint("Then journal view is opened and Omnibar additional buttons are not displayed")
        XCTAssertTrue(journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertFalse(omnibarView.button(OmniBarLocators.Buttons.refreshButton.accessibilityIdentifier).exists)
        
        testRailPrint("When I open web view")
        CardTestView().navigateToWebView()
        
        testRailPrint("Then Webview is opened and Journal is closed")
        XCTAssertTrue(omnibarView.group(WebViewLocators.Images.browserTabBar.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(omnibarView.button(OmniBarLocators.Buttons.refreshButton.accessibilityIdentifier).exists)
        XCTAssertFalse(journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier).exists)
    }
}
