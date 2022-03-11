//
//  AppDelegate+Onboarding.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/12/2021.
//

import Foundation

extension AppDelegate: OnboardingManagerDelegate {
    func onboardingManagerDidFinish(userDidSignUp: Bool) {
        guard windows.isEmpty else { return }
        let window = createWindow(frame: nil, restoringTabs: false)
        if userDidSignUp {
            window?.state.displayWelcomeTour()
        }
    }
}
