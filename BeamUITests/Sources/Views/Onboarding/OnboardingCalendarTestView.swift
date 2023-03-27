//
//  OnboardingCalendarTestView.swift
//  BeamUITests
//
//  Created by Jean-Louis Darmon on 12/10/2022.
//

import Foundation

enum OnboardingCalendarViewLocators {

    enum Buttons: String, CaseIterable, UIElement {
        case skipButton = "skip_action"
    }
}

class OnboardingCalendarTestView: BaseView {
    @discardableResult
    func clickSkipButton() -> WebTestView {
        button(OnboardingCalendarViewLocators.Buttons.skipButton.accessibilityIdentifier).clickOnExistence()
        return WebTestView()
    }
}
