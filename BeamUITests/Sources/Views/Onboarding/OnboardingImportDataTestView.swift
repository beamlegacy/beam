//
//  OnboardingImportDataTestView.swift
//  BeamUITests
//
//  Created by Andrii on 21/03/2022.
//

import Foundation
import XCTest

class OnboardingImportDataTestView: BaseView {
    
    func clickSkipButton() -> JournalTestView {
        button(OnboardingImportDataViewLocators.Buttons.skipButton.accessibilityIdentifier).clickOnExistence()
        return JournalTestView()
    }
    
}
