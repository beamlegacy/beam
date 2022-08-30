//
//  AboutPreferencesTestView.swift
//  BeamUITests
//
//  Created by Andrii on 07/04/2022.
//

import Foundation
import XCTest

class AboutPreferencesTestView: PreferencesBaseView {
    
    @discardableResult
    func clickFeatureRequestButton() -> AboutPreferencesTestView {
        button(AboutPreferencesViewLocators.Buttons.reportFeatureButton.accessibilityIdentifier).clickOnHittable()
        return self
    }
    
    @discardableResult
    func clickReportBugButton() -> AboutPreferencesTestView {
        button(AboutPreferencesViewLocators.Buttons.reportBugButton.accessibilityIdentifier).clickOnHittable()
        return self
    }
    
    @discardableResult
    func clickFollowTwitterButton() -> AboutPreferencesTestView {
        button(AboutPreferencesViewLocators.Buttons.followTwitterButton.accessibilityIdentifier).clickOnHittable()
        return self
    }
    
    @discardableResult
    func clickTermsOfServiceHyperlink() -> AboutPreferencesTestView {
        staticText(AboutPreferencesViewLocators.StaticTexts.termsOfServicesHyperlink.accessibilityIdentifier).hoverAndTapInTheMiddle()
        return self
    }
    
    @discardableResult
    func clickPrivacyPolicyHyperlink() -> AboutPreferencesTestView {
        staticText(AboutPreferencesViewLocators.StaticTexts.privacyPolicyHyperlink.accessibilityIdentifier).hoverAndTapInTheMiddle()
        return self
    }
    
}
