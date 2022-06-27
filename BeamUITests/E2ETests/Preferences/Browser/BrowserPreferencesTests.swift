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
    let searchWord = "beam"
    
    override func setUpWithError() throws {
        step ("GIVEN I open Browser preferences"){
            launchApp()
            openBrowserPrefs()
            browserPref.waitForViewToLoad()
        }
    }
    
    private func openBrowserPrefs() {
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(preferenceView: .browser)
    }
    
    private func assertSearchEngine(_ engine: BrowserPreferencesViewLocators.MenuItemsSearchEngine, _ expectedTabTitle: String, _ prepareNextSteps: Bool = true) {
        
        step("WHEN I select \(engine) ") {
            browserPref.selectSearchEngine(engine)
            shortcutHelper.shortcutActionInvoke(action: .close)
            waitForDoesntExist(browserPref.getSuggestionEngineCheckbox())
            OmniBoxTestView().searchInOmniBox(searchWord, true)
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
    
    func testSetDefaultBrowserButton() {
        //scenario is quite primitive due to limitation of the system alerts usage, only button existence and hittable is possible
        step("THEN Set default browser button exists and is hittable") {
            XCTAssertTrue(browserPref.getSetDefaultButton().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(browserPref.getSetDefaultButton().isHittable)
        }
    }
    
    func testClearCacheButton() {
        step("THEN Set default browser button exists and is hittable") {
            XCTAssertTrue(browserPref.getClearCacheButtonButton().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(browserPref.getClearCacheButtonButton().isHittable)
        }
        //To be expanded after https://linear.app/beamapp/issue/BE-4545/uitest-menu-to-populate-browser-cache and 
    }
    
    func testEnableCaptureSoundsCheckbox() {
        //scenario is quite primitive due to impossibility to assert sounds existence
        step("THEN Enable Capture Sounds Checkbox exists and is enabled") {
            XCTAssertTrue(browserPref.getCaptureSoundsCheckbox().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(browserPref.getCaptureSoundsCheckbox().isSettingEnabled())
        }
    }
    
    func testSearchEngineSelection() {
        
        let expectedGoogleTitle = "Google"
        let expectedDuckTitle = "\(searchWord) at DuckDuckGo"
        let expectedEcosiaTitle = "\(searchWord) - Ecosia - Web"
        
        assertSearchEngine(.duck, expectedDuckTitle)
        assertSearchEngine(.ecosia, expectedEcosiaTitle)
        assertSearchEngine(.google, expectedGoogleTitle, false)
        
    }
    
    func testIncludeSearchEngineSuggestion() {
        
        step("THEN engine suggestion checkbox exists and is enabled by default") {
            XCTAssertTrue(browserPref.getSuggestionEngineCheckbox().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertEqual(browserPref.getSuggestionEngineCheckbox().title, "Include search engine suggestions")
            XCTAssertTrue(browserPref.getSuggestionEngineCheckbox().isSettingEnabled())
            shortcutHelper.shortcutActionInvoke(action: .close)
        }
        
        /*step("THEN engine suggestion is available during the web search") {
            blocked by https://linear.app/beamapp/issue/BE-4533/add-the-way-to-define-search-engine-type-in-omnibox-for-xcuitests
        }*/
        
        //negative scenario test is blocked by https://linear.app/beamapp/issue/BE-4532/search-engine-suggestion-appears-even-with-the-option-disabled
        //step("THEN search engine suggestion is unavailable on checkbox disableing") { }
    }
    
    func testImportBrowserDataTrigger() {
        
        step("THEN Import browser click triggers Onboarding import view appearing") {
            XCTAssertTrue(browserPref.staticText(BrowserPreferencesViewLocators.StaticTexts.importPasswordlabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            browserPref.getImportButton().tapInTheMiddle()
            XCTAssertTrue(OnboardingImportDataTestView().waitForImportDataViewLoad())
        }
    }
    
    func testDownloadsFolderSelection() {
        step("THEN Downloads folder selection options are correct") {
            browserPref.triggerDownloadFolderSelection()
            for item in BrowserPreferencesViewLocators.MenuItemsDownload.allCases {
                XCTAssertTrue(browserPref.menuItem(item.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout), "\(item.accessibilityIdentifier) is not in the search engines list")
            }
        }
        
        //Folder selection cancellation test is blocked by //https://linear.app/beamapp/issue/BE-4523/no-download-folder-is-selected-on-cancellation
        /*step("THEN I successfully cancel folder selection") {
            
        }*/
        
        //To be unblocked via https://linear.app/beamapp/issue/BE-4531/reset-downloads-destination-folder-uitest-menu
        /*step("THEN I can select another folder") {
            browserPref.selectDownloadFolder(.other)
            let finderWindow = XCUIApplication().dialogs["Open"]
            XCTAssertTrue(finderWindow.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            finderWindow.buttons["OKButton"].clickOnExistence()
            XCTAssertTrue(waitForDoesntExist(finderWindow))
        }*/
    }
}
