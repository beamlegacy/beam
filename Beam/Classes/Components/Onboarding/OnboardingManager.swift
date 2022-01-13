//
//  OnboardingManager.swift
//  Beam
//
//  Created by Remi Santos on 12/11/2021.
//

import Foundation
import Combine

struct OnboardingStep: Equatable {
    enum StepType {
        case welcome
        case profile
        case emailConnect
        case emailConfirm
        case imports
        case loading
    }

    let type: StepType
    var title: String?
}

protocol OnboardingManagerDelegate: AnyObject {
    func onboardingManagerDidFinish()
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
        /// return true to go to the next step
        var onClick: (() -> Bool)?
    }

    @Published var needsToDisplayOnboard: Bool
    @Published private(set) var currentStep: OnboardingStep
    @Published var actions = [StepAction]()
    var currentStepIsFromHistory = false
    var onlyLogin: Bool = false
    var onlyImport: Bool = false
    weak var delegate: OnboardingManagerDelegate?
    var temporaryCredentials: (email: String, password: String)?

    private(set) var stepsHistory = [OnboardingStep]()
    private weak var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    init(onlyLogin: Bool = false, onlyImport: Bool = false) {
        var needsToDisplayOnboard = Configuration.env != .test && Persistence.Authentication.hasSeenOnboarding != true
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
        if onlyImport {
            step = OnboardingStep(type: .imports)
        }
        self.needsToDisplayOnboard = needsToDisplayOnboard
        currentStep = step ?? OnboardingStep(type: .welcome)
        self.onlyLogin = onlyLogin
    }

    func resetOnboarding() {
        currentStep = OnboardingStep(type: .welcome)
        actions = []
        stepsHistory.removeAll()
        currentStepIsFromHistory = false
        needsToDisplayOnboard = true
        temporaryCredentials = nil
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
            dismissOnboardingWindow()
            delegate?.onboardingManagerDidFinish()
        }
    }

    private func stepAfter(step: OnboardingStep) -> OnboardingStep? {
        switch step.type {
        case .welcome, .emailConnect, .emailConfirm:
            if AuthenticationManager.shared.isAuthenticated && AuthenticationManager.shared.username == nil {
                return OnboardingStep(type: .profile)
            } else {
                return onlyLogin ? nil : OnboardingStep(type: .imports)
            }
        case .profile:
            return onlyLogin ? nil : OnboardingStep(type: .imports)
        case .imports:
            return nil
        default:
            return nil
        }
    }

    private func onboardingDidStart() {
        Persistence.Authentication.hasSeenOnboarding = true
        AuthenticationManager.shared.isAuthenticatedPublisher.sink { [weak self] isAuthenticated in
            if isAuthenticated {
                self?.stepsHistory.removeAll()
            }
        }.store(in: &cancellables)
    }

    private func onboardingDidFinish() {
        temporaryCredentials = nil
        cancellables.removeAll()
    }
}

// MARK: - Window management
extension OnboardingManager {

    func presentOnboardingWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let newWindow = OnboardingWindow(contentRect: NSRect(x: 0, y: 0, width: 512, height: 600), model: self)
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.isReleasedWhenClosed = false
        window = newWindow
        onboardingDidStart()
        return
    }

    func dismissOnboardingWindow() {
        window?.close()
        window = nil
        onboardingDidFinish()
    }
}
