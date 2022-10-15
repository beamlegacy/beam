//
//  OnboardingMinimalTestView.swift
//  BeamUITests
//
//  Created by Jean-Louis Darmon on 12/10/2022.
//

import Foundation

enum OnboardingMinimalViewLocators {
    enum Buttons: String, CaseIterable, UIElement {
        case continueButton = "Continue"
    }

    enum StaticTexts: String, CaseIterable, UIElement {
        case onboardingWelcomeTitle = "Welcome to Beam"
    }
}

class OnboardingMinimalTestView: BaseView {
    @discardableResult
    func waitForLandingViewToLoad() -> Bool {
        return staticText(OnboardingMinimalViewLocators.StaticTexts.onboardingWelcomeTitle.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
    }

    @discardableResult
    func continueOnboarding() -> OnboardingCalendarTestView {
        button(OnboardingMinimalViewLocators.Buttons.continueButton.accessibilityIdentifier).clickOnExistence()
        return OnboardingCalendarTestView()
    }
}

