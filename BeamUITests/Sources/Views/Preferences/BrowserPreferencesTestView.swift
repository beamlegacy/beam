//
//  BrowserPreferencesTestView.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 22.06.2022.
//

import Foundation
import XCTest

class BrowserPreferencesTestView: PreferencesBaseView {
    
    func getImportButton() -> XCUIElement {
        return button(BrowserPreferencesViewLocators.Buttons.importButton.accessibilityIdentifier)
    }
    
    func getSetDefaultButton() -> XCUIElement {
        return button(BrowserPreferencesViewLocators.Buttons.setDefaultButton.accessibilityIdentifier)
    }
    
    func getClearCacheButtonButton() -> XCUIElement {
        return button(BrowserPreferencesViewLocators.Buttons.clearCacheButton.accessibilityIdentifier)
    }
    
    func getCaptureSoundsCheckbox() -> XCUIElement {
        return checkBox(BrowserPreferencesViewLocators.Checkboxes.captureSounds.accessibilityIdentifier)
    }
    
    func getSuggestionEngineCheckbox() -> XCUIElement {
        return checkBox(BrowserPreferencesViewLocators.Checkboxes.searchEngine.accessibilityIdentifier)
    }
    
    func getCMDClickCheckbox() -> XCUIElement {
        return checkBox(BrowserPreferencesViewLocators.Checkboxes.cmdClick.accessibilityIdentifier)
    }
    
    func getSwitchTabsCheckbox() -> XCUIElement {
        return checkBox(BrowserPreferencesViewLocators.Checkboxes.switchTabs.accessibilityIdentifier)
    }
    
    @discardableResult
    func selectDownloadFolder(_ item: BrowserPreferencesViewLocators.MenuItemsDownload) -> BrowserPreferencesTestView {
        popUpButton(BrowserPreferencesViewLocators.Buttons.downloadFolderButton.accessibilityIdentifier).tapInTheMiddle()
        menuItem(item.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func triggerDownloadFolderSelection() -> BrowserPreferencesTestView {
        getFolderSelectionElement().tapInTheMiddle()
        return self
    }
    
    func getFolderSelectionElement() -> XCUIElement {
        return popUpButton(BrowserPreferencesViewLocators.Buttons.downloadFolderButton.accessibilityIdentifier)
    }
    
    @discardableResult
    func clickSearchEngineDropdown() -> BrowserPreferencesTestView {
        popUpButton(BrowserPreferencesViewLocators.Buttons.searchEngine.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func selectSearchEngine(_ engine: BrowserPreferencesViewLocators.MenuItemsSearchEngine) {
        clickSearchEngineDropdown()
        menuItem(engine.accessibilityIdentifier).clickOnExistence()
    }
    
    @discardableResult
    func waitForViewToLoad() -> Bool {
        return getSetDefaultButton().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
}
