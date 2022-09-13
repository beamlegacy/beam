//
//  PrivacyPreferencesTestView.swift
//  BeamUITests
//
//  Created by Quentin Valero on 10/05/2022.
//

import Foundation
import XCTest

class PrivacyPreferencesTestView: PreferencesBaseView {
    
    let sitesColumnTitle = "Sites"
    let enterUrlCell = "Enter URL"

    var allowListTables : XCUIElementQuery {
            get {
                return app.windows["Privacy"].sheets.tables
            }
        }
    
    @discardableResult
    func accessAllowList() -> PrivacyPreferencesTestView {
        button(PrivacyPreferencesViewLocators.Buttons.allowListManage.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func getAllowListUrlByIndex(_ index: Int) -> XCUIElement {
        return allowListTables.children(matching: .tableRow).element(boundBy: index).textFields[sitesColumnTitle]
    }
    
    func isAllowListFilled() -> Bool {
        return allowListTables.children(matching: .tableRow).element.textFields[sitesColumnTitle].firstMatch.waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }

    @discardableResult
    func addAllowUrl() -> PrivacyPreferencesTestView {
        button(PrivacyAllowListPreferencesViewLocators.Buttons.addURL.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func fillNewUrl(_ host: String) -> PrivacyPreferencesTestView {
        allowListTables.textFields[enterUrlCell].clickAndType(host)
        self.typeKeyboardKey(.enter)
        return self
    }
    
    @discardableResult
    func selectAllowedUrlCell(_ host: String) -> PrivacyPreferencesTestView {
        allowListTables.textFields[host].clickOnExistence()
        return self
    }
    
    @discardableResult
    func removeAllowUrl() -> PrivacyPreferencesTestView {
        button(PrivacyAllowListPreferencesViewLocators.Buttons.removeURL.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func cancelAllowList() -> PrivacyPreferencesTestView {
        button(PrivacyAllowListPreferencesViewLocators.Buttons.cancelButton.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func saveAllowList() -> PrivacyPreferencesTestView {
        button(PrivacyAllowListPreferencesViewLocators.Buttons.applyButton.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func sortAllowedUrls() -> PrivacyPreferencesTestView {
        allowListTables.buttons[sitesColumnTitle].clickOnExistence()
        return self
    }
    
    @discardableResult
    func searchForAllowedUrlBy(_ searchKeyword: String) -> PrivacyPreferencesTestView {
        textField(PrivacyAllowListPreferencesViewLocators.TextFields.searchField.accessibilityIdentifier).focusAndTypeTextOnExistence(searchKeyword)
        return self
    }
    
    func isAllowedUrlDisplayedBy(_ text: String) -> Bool {
        return allowListTables.children(matching: .tableRow).element.textFields[text].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func getInsideAdBlockerSettingElement() -> XCUIElement {
        return checkBox(PrivacyPreferencesViewLocators.CheckboxTexts.adsCheckbox.accessibilityIdentifier)
    }
    
    @discardableResult
    func clickInsideAdBlockerSetting() -> PrivacyPreferencesTestView {
        checkBox(PrivacyPreferencesViewLocators.CheckboxTexts.adsCheckbox.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func getSocialMediaButtonBlockerSettingElement() -> XCUIElement {
        return checkBox(PrivacyPreferencesViewLocators.CheckboxTexts.trackersSocialMedia.accessibilityIdentifier)
    }
    
    @discardableResult
    func clickInsideSocialMediaButtonBlockerSetting() -> PrivacyPreferencesTestView {
        checkBox(PrivacyPreferencesViewLocators.CheckboxTexts.trackersSocialMedia.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func getCookieBannerBlockerSettingElement() -> XCUIElement {
        return checkBox(PrivacyPreferencesViewLocators.CheckboxTexts.annoyancesCookieBanners.accessibilityIdentifier)
    }
    
    @discardableResult
    func clickCookieBannerBlockerSetting() -> PrivacyPreferencesTestView {
        checkBox(PrivacyPreferencesViewLocators.CheckboxTexts.annoyancesCookieBanners.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func getBannerPopupBlockerSettingElement() -> XCUIElement {
        return checkBox(PrivacyPreferencesViewLocators.CheckboxTexts.annoyancesBanners.accessibilityIdentifier)
    }
    
    @discardableResult
    func clickBannerPopupBlockerSetting() -> PrivacyPreferencesTestView {
        checkBox(PrivacyPreferencesViewLocators.CheckboxTexts.annoyancesBanners.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
}
