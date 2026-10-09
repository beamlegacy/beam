//
//  OnboardingTests.swift
//  BeamUITests
//
//  Created by Andrii on 24/11/2021.
//

import Foundation
import XCTest

class OnboardingTests: BaseTest {

    let onboardingMinimalView = OnboardingMinimalTestView()
    let onboardingCalendarView = OnboardingCalendarTestView()

    override func setUp()  {
        step("Given I enable onboarding"){
            super.setUp()
            uiMenu.invoke(.showOnboarding)
        }
    }

    func testCompleteOnboarding() {
        testrailId("C658")
        step("Then onboarding welcome view is displayed"){
            XCTAssertTrue(onboardingMinimalView.waitForLandingViewToLoad(), "Onboarding view wasn't loaded")
        }

        step("When I continue onboarding"){
            onboardingMinimalView.continueOnboarding()
        }

        step("Then I'm on Journal after skipping calendar setup"){
            XCTAssertEqual(onboardingCalendarView.clickSkipButton().closeTab().getNumberOfTabs(), 0)
            XCTAssertTrue(JournalTestView().waitForJournalViewToLoad().isJournalOpened(), "Journal view didn't load")
        }
    }

}
