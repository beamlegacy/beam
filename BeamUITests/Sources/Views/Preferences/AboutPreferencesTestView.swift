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
    
}
