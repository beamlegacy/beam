//
//  OnboardingImportDataTestView.swift
//  BeamUITests
//
//  Created by Andrii on 21/03/2022.
//

import Foundation
import XCTest

class OnboardingImportDataTestView: BaseView {
    
    @discardableResult
    func clickSkipButton() -> JournalTestView {
        button(OnboardingImportDataViewLocators.Buttons.skipButton.accessibilityIdentifier).clickOnExistence()
        return JournalTestView()
    }
    
    @discardableResult
    func clickBackButton() -> OnboardingLandingTestView {
        staticText(OnboardingImportDataViewLocators.Buttons.backButton.accessibilityIdentifier).clickOnExistence()
        return OnboardingLandingTestView()
    }
    
    @discardableResult
    func waitForImportDataViewLoad() -> Bool {
        return staticText(OnboardingImportDataViewLocators.StaticTexts.viewTitle.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func getHistoryCheckboxTitle() -> XCUIElement {
        return staticText(OnboardingImportDataViewLocators.StaticTexts.historyCheckboxTitle.accessibilityIdentifier)
    }
    
    func getPasswordCheckboxTitle() -> XCUIElement {
        return staticText(OnboardingImportDataViewLocators.StaticTexts.passwordCheckboxTitle.accessibilityIdentifier)
    }
    
    func getSafariDescriptionRow1() -> XCUIElement {
        return staticText(OnboardingImportDataViewLocators.StaticTexts.safariDescription1.accessibilityIdentifier)
    }
    
    func getSafariDescriptionRow2() -> XCUIElement {
        return staticText(OnboardingImportDataViewLocators.StaticTexts.safariDescription2.accessibilityIdentifier)
    }
    
    func getMozillaDescriptionRow1() -> XCUIElement {
        return staticText(OnboardingImportDataViewLocators.StaticTexts.mozillaDescription1.accessibilityIdentifier)
    }
    
    func getMozillaDescriptionRow2() -> XCUIElement {
        return staticText(OnboardingImportDataViewLocators.StaticTexts.mozillaDescription2.accessibilityIdentifier)
    }
    
    func getSafariMozillaDescriptionRow3() -> XCUIElement {
        return staticText(OnboardingImportDataViewLocators.StaticTexts.safariMozillaDescription3.accessibilityIdentifier)
    }
    
    func getCSVDescriptionRow1() -> XCUIElement {
        return staticText(OnboardingImportDataViewLocators.StaticTexts.csvDescriptionRow1.accessibilityIdentifier)
    }
    
    func getCSVDescriptionRow2() -> XCUIElement {
        return staticText(OnboardingImportDataViewLocators.StaticTexts.csvDescriptionRow2.accessibilityIdentifier)
    }
    
    func getChooseCSVButton() -> XCUIElement {
        return button(OnboardingImportDataViewLocators.Buttons.csvButton.accessibilityIdentifier)
    }
    
    @discardableResult
    func selectBrowser(_ browser: OnboardingImportDataViewLocators.Browsers) -> OnboardingImportDataTestView {
        image(OnboardingImportDataViewLocators.Images.browsersDropDownIcon.accessibilityIdentifier).tapInTheMiddle()
        app.windows.menus.menuItems[browser.rawValue].click()
        return self
    }
    
    func getImportButton() -> XCUIElement {
        return button(OnboardingImportDataViewLocators.Buttons.importButton.accessibilityIdentifier)
    }
    
}
