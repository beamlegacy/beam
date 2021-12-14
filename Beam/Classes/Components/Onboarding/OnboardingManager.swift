//
//  OnboardingManager.swift
//  Beam
//
//  Created by Remi Santos on 12/11/2021.
//

import Foundation

struct OnboardingStep: Equatable {

    enum StepType {
        case welcome
        case profile
        case emailConnect
        case imports
        case loading
    }

    let type: StepType
    var title: String?
}

class OnboardingManager: ObservableObject {

    struct StepAction: Identifiable, Equatable {
        static func == (lhs: OnboardingManager.StepAction, rhs: OnboardingManager.StepAction) -> Bool {
            lhs.id == rhs.id
        }

        var id = UUID()
        var title: String
        var enabled: Bool
        var secondary: Bool = false
        /// return true to go to the next step
        var onClick: (() -> Bool)?
    }

    @Published var needsToDisplayOnboard: Bool
    @Published private(set) var currentStep: OnboardingStep
    @Published var actions = [StepAction]()
    var currentStepIsFromHistory = false
    private(set) var stepsHistory = [OnboardingStep]()

    init() {
        var needsToDisplayOnboard = Configuration.env != "test" && Persistence.Authentication.hasSeenOnboarding != true
        var step: OnboardingStep?
        if needsToDisplayOnboard {
            if AuthenticationManager.shared.isAuthenticated {
                if AuthenticationManager.shared.username != nil {
                    needsToDisplayOnboard = false
                } else {
                    step = OnboardingStep(type: .profile)
                }
            } else {
                step = OnboardingStep(type: .welcome)
            }
        }
        self.needsToDisplayOnboard = needsToDisplayOnboard
        currentStep = step ?? OnboardingStep(type: .welcome)
        Persistence.Authentication.hasSeenOnboarding = true
    }

    func resetOnboarding() {
        currentStep = OnboardingStep(type: .welcome)
        actions = []
        stepsHistory.removeAll()
        currentStepIsFromHistory = false
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
            if AuthenticationManager.shared.isAuthenticated {
                stepsHistory.removeAll()
            } else {
                stepsHistory.append(previous)
            }
        } else {
            needsToDisplayOnboard = false
        }
    }

    private func stepAfter(step: OnboardingStep) -> OnboardingStep? {
        switch step.type {
        case .welcome, .emailConnect:
            if AuthenticationManager.shared.isAuthenticated && AuthenticationManager.shared.username == nil {
                return OnboardingStep(type: .profile)
            } else {
                return OnboardingStep(type: .imports)
            }
        case .profile:
            return OnboardingStep(type: .imports)
        case .imports:
            return nil
        default:
            return nil
        }
    }
}
