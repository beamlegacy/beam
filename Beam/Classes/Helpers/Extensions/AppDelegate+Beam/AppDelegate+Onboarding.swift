//
//  AppDelegate+Onboarding.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/12/2021.
//

import Foundation

extension AppDelegate: OnboardingManagerDelegate {
    func onboardingManagerDidFinish(isNewUser: Bool) {
        let window = windows.first ?? createWindow(frame: nil)
        if isNewUser {
            window?.state.displayWelcomeTour()
        }
    }
}
