//
//  AppDelegate+Onboarding.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/12/2021.
//

import Foundation

extension AppDelegate: OnboardingManagerDelegate {
    func onboardingManagerDidFinish() {
        guard windows.isEmpty else { return }
        createWindow(frame: nil, restoringTabs: false)
    }
}
