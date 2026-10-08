//
//  OnboardingManager.swift
//  Beam
//
//  Created by Remi Santos on 12/11/2021.
//

import Foundation
import Combine
import BeamCore
import SwiftUI

struct OnboardingStep: Equatable {
    enum StepType: String {
        case minimalWelcome
        case setupCalendar
        case imports
    }

    let type: StepType

    var canGoBack: Bool {
        false
    }
}

protocol OnboardingManagerDelegate: AnyObject {
    func onboardingManagerDidFinish(isNewUser: Bool)
}

class OnboardingManager: ObservableObject {

    struct StepAction: Identifiable, Equatable {
        static func == (lhs: OnboardingManager.StepAction, rhs: OnboardingManager.StepAction) -> Bool {
            lhs.id == rhs.id
        }

        var id = UUID().uuidString
        var title: String
        var enabled: Bool
        var secondary: Bool = false
        var customVariant: ActionableButtonVariant?
        var customWidth: CGFloat?
        var alignment = HorizontalAlignment.trailing
        /// return true to go to the next step
        var onClick: (() -> Bool)?
    }

    @Published private(set) var needsToDisplayOnboard: Bool
    @Published private(set) var currentStep: OnboardingStep
    @Published var actions = [StepAction]()
    @Published var viewIsLoading = false
    @Published private(set) var stepsHistory = [OnboardingStep]()

    private let analyticsCollector: AnalyticsCollector?
    let onboardingNoteCreator = OnboardingNoteCreator()

    var currentStepIsFromHistory = false
    var onlyImport: Bool = false
    weak var delegate: OnboardingManagerDelegate?

    private weak var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    init(onlyImport: Bool = false, analyticsCollector: AnalyticsCollector? = nil) {
        self.analyticsCollector = analyticsCollector

        let needsToDisplayOnboard = Configuration.env != .test && Configuration.env != .uiTest && Persistence.Authentication.hasSeenOnboarding != true
        var step: OnboardingStep?
        if needsToDisplayOnboard {
            step = OnboardingStep(type: .minimalWelcome)
        }
        if onlyImport {
            step = OnboardingStep(type: .imports)
        }
        self.needsToDisplayOnboard = needsToDisplayOnboard
        currentStep = step ?? OnboardingStep(type: .minimalWelcome)
    }

    func resetOnboarding() {
        currentStep = OnboardingStep(type: .minimalWelcome)
        actions = []
        stepsHistory.removeAll()
        cancellables.removeAll()
        currentStepIsFromHistory = false
        viewIsLoading = false
        onlyImport = false
    }

    func forceDisplayOnboarding() {
        resetOnboarding()
        needsToDisplayOnboard = true
        Persistence.Authentication.hasSeenOnboarding = false
    }

    func backToPreviousStep() {
        guard let previous = stepsHistory.popLast() else { return }
        actions = []
        currentStepIsFromHistory = true
        currentStep = previous
    }

    func advanceToNextStep(_ nextStep: OnboardingStep? = nil) {
        let previous = currentStep
        actions = []
        currentStepIsFromHistory = false
        if let nextStep = nextStep ?? stepAfter(step: previous) {
            currentStep = nextStep
            viewIsLoading = false
            if !nextStep.canGoBack {
                stepsHistory.removeAll()
            } else {
                stepsHistory.append(previous)
            }
            analyticsCollector?.record(event: OnboardingEvent(step: currentStep))
        } else {
            needsToDisplayOnboard = false
            dismissOnboardingWindow()
            analyticsCollector?.record(event: OnboardingEvent(step: nil))
        }
    }

    private func stepAfter(step: OnboardingStep) -> OnboardingStep? {
        switch step.type {
        case .minimalWelcome:
            return OnboardingStep(type: .setupCalendar)
        case .imports, .setupCalendar:
            return nil
        }
    }

    private func onboardingDidStart() {

    }

    private func onboardingDidFinish() {
        let isNewUser = !onlyImport
        delegate?.onboardingManagerDidFinish(isNewUser: isNewUser)
        if isNewUser {
            onboardingNoteCreator.createOnboardingNotes(data: BeamData.shared)
        }
        Persistence.Authentication.hasSeenOnboarding = true
        resetOnboarding()
    }
}

// MARK: - Window management
extension OnboardingManager {

    func presentOnboardingWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let newWindow = OnboardingWindow(model: self)
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.isReleasedWhenClosed = false
        window = newWindow
        onboardingDidStart()
        analyticsCollector?.record(event: OnboardingEvent(step: currentStep))
        return
    }

    func dismissOnboardingWindow() {
        onboardingDidFinish()
        window?.close()
        window = nil
    }

    func windowDidClose() {
        guard onlyImport else { return }
        resetOnboarding()
        needsToDisplayOnboard = false
    }
}
