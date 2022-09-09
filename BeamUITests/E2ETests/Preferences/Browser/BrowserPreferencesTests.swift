//
//  BrowserPreferencesTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 22.06.2022.
//

import Foundation
import XCTest

class BrowserPreferencesTests: BaseTest {
    
    let browserPref = BrowserPreferencesTestView()
    let omnibox = OmniBoxTestView()
    let finder = FinderView()
    let searchWord = "beam"
    
    override func setUpWithError() throws {
        step ("GIVEN I launch the app"){
            launchApp()
        }
    }
    
    private func openBrowserPrefs() {
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(preferenceView: .browser)
        browserPref.waitForViewToLoad()
    }
    
    private func assertSearchEngine(_ engine: BrowserPreferencesViewLocators.MenuItemsSearchEngine, _ expectedTabTitle: String, _ prepareNextSteps: Bool = true) {
        
        step("WHEN I select \(engine) ") {
            browserPref.selectSearchEngine(engine)
            shortcutHelper.shortcutActionInvoke(action: .close)
            waitForDoesntExist(browserPref.getSuggestionEngineCheckbox())
            omnibox.searchInOmniBox(searchWord, true)
            webView.waitForWebViewToLoad()
        }
        
        step("THEN \(expectedTabTitle) is displayed for searching:'\(searchWord)'") {
            let title = webView.getBrowserTabTitleValueByIndex(index: 0)
            if engine == .google { //multiple localizations handling e.g. "beam - Recherche Google"
                XCTAssertTrue(title.starts(with: searchWord) && title.contains(expectedTabTitle))
            } else {
                XCTAssertEqual(title, expectedTabTitle)
            }
        }
        
        if prepareNextSteps {
            step("GIVEN I open preferences") {
                shortcutHelper.shortcutActionInvoke(action: .close)
                JournalTestView().waitForJournalViewToLoad()
                shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            }
        }
    }
    
    private func assertSearchEngineSuggestion(_ engine: BrowserPreferencesViewLocators.MenuItemsSearchEngine, _ prepareNextSteps: Bool = true, _ searchEngingeSuggestionEnabled: Bool = true) {
        
        step("WHEN I select \(engine) ") {
            openBrowserPrefs()
            browserPref.selectSearchEngine(engine)
            shortcutHelper.shortcutActionInvoke(action: .close)
            waitForDoesntExist(browserPref.getSuggestionEngineCheckbox())
            omnibox.searchInOmniBox(searchWord, false)
        }
        
        step("THEN omnibox autocomplete has search enging suggestion") {
            let firstAutocompleteResult = omnibox.getAutocompleteResults().firstMatch
            if searchEngingeSuggestionEnabled {
                waitForElementLabelContains(engine.rawValue, firstAutocompleteResult)
            } else {
                XCTAssertFalse(waitForElementLabelContains(engine.rawValue, firstAutocompleteResult))
            } //multiple localizations handling e.g. "beam - Recherche Google"
        }
        
        if prepareNextSteps {
            step("GIVEN I open preferences") {
                shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            }
        }
    }
    
    func testSetDefaultBrowserButton() {
        testrailId("C588")
        //scenario is quite primitive due to limitation of the system alerts usage, only button existence and hittable is possible
        step("THEN Set default browser button exists and is hittable") {
            openBrowserPrefs()
            XCTAssertTrue(browserPref.getSetDefaultButton().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(browserPref.getSetDefaultButton().isHittable)
        }
    }
    
    func testClearCacheButton() {
        testrailId("C598")
        step("THEN Set default browser button exists and is hittable") {
            openBrowserPrefs()
            XCTAssertTrue(browserPref.getClearCacheButtonButton().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(browserPref.getClearCacheButtonButton().isHittable)
        }
        //To be expanded after https://linear.app/beamapp/issue/BE-4545/uitest-menu-to-populate-browser-cache and 
    }
    
    func testEnableCaptureSoundsCheckbox() {
        testrailId("C597")
        //scenario is quite primitive due to impossibility to assert sounds existence
        step("THEN Enable Capture Sounds Checkbox exists and is enabled") {
            openBrowserPrefs()
            XCTAssertTrue(browserPref.getCaptureSoundsCheckbox().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(browserPref.getCaptureSoundsCheckbox().isSettingEnabled())
        }
    }
    
    func testSearchEngineSelection() {
        testrailId("C589")
        let expectedGoogleTitle = "Google"
        let expectedDuckTitle = "\(searchWord) at DuckDuckGo"
        let expectedEcosiaTitle = "\(searchWord) - Ecosia - Web"
        
        openBrowserPrefs()
        assertSearchEngine(.duck, expectedDuckTitle)
        assertSearchEngine(.ecosia, expectedEcosiaTitle)
        assertSearchEngine(.google, expectedGoogleTitle, false)
        
    }
    
    func testIncludeSearchEngineSuggestion() {
        testrailId("C590")
        step("THEN engine suggestion is available during the web search") {
            openBrowserPrefs()
            assertSearchEngineSuggestion(.duck)
            assertSearchEngineSuggestion(.google)
            assertSearchEngineSuggestion(.ecosia)
        }
        
        step("THEN search engine suggestion is unavailable on checkbox disabling") {
            XCTAssertTrue(browserPref.getSuggestionEngineCheckbox().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertEqual(browserPref.getSuggestionEngineCheckbox().title, "Include search engine suggestions")
            browserPref.getSuggestionEngineCheckbox().tapInTheMiddle()
            assertSearchEngineSuggestion(.google, false, false)
        }
    }
    
    func testImportBrowserDataTrigger() {
        testrailId("C591")
        step("THEN Import browser click triggers Onboarding import view appearing") {
            openBrowserPrefs()
            XCTAssertTrue(browserPref.staticText(BrowserPreferencesViewLocators.StaticTexts.importPasswordlabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            browserPref.getImportButton().tapInTheMiddle()
            XCTAssertTrue(OnboardingImportDataTestView().waitForImportDataViewLoad())
        }
    }
    
    func testDownloadsFolderSelection() {
        testrailId("C592")
        step("THEN Downloads folder selection options are correct") {
            openBrowserPrefs()
            browserPref.triggerDownloadFolderSelection()
            for item in BrowserPreferencesViewLocators.MenuItemsDownload.allCases {
                XCTAssertTrue(browserPref.menuItem(item.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout), "\(item.accessibilityIdentifier) is not in download folders list")
            }
        }
        
        if !isBigSurOS() { //impossible to get selected folder on Big Sur only
            step("THEN I successfully cancel folder selection") {
                browserPref.menuItem(BrowserPreferencesViewLocators.MenuItemsDownload.other.accessibilityIdentifier).hoverAndTapInTheMiddle()
                finder.clickCancel()
                XCTAssertTrue(waitForStringValueEqual(BrowserPreferencesViewLocators.MenuItemsDownload.downloads.accessibilityIdentifier, browserPref.getFolderSelectionElement()))
            }
        
            step("THEN I can select another folder") {
                browserPref.selectDownloadFolder(.other)
                XCTAssertTrue(finder.isFinderOpened())
                finder.clickOkSelect()
                XCTAssertTrue(waitForStringValueEqual(BrowserPreferencesViewLocators.MenuItemsDownload.other.accessibilityIdentifier, browserPref.getFolderSelectionElement()))
            }
        }
    }
}
