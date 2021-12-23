//
//  AppDelegate+Onboarding.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/12/2021.
//

import Foundation
extension AppDelegate {
    func showOnboardingWindow(model: OnboardingManager) {
        if let onboardingWindow = onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(window)
            return
        }
        onboardingWindow = OnboardingWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 520), model: model)
        onboardingWindow?.center()
        onboardingWindow?.makeKeyAndOrderFront(window)
    }

    func closeOnboardingWindow() {
        self.onboardingWindow?.close()
    }
}
