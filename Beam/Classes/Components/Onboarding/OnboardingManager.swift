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
        case welcome
        case profile
        case emailConnect
        case setupPrivateKey
        case lostPrivateKey
        case emailConfirm
        case imports
        case savePrivateKey
        case loading
    }

    let type: StepType
    var title: String?

    var canGoBack: Bool {
        switch type {
        case .welcome, .profile, .imports, .savePrivateKey, .loading, .minimalWelcome, .setupCalendar:
            return false
        default:
            return true
        }
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
    var onlyConnect: Bool = false
    var onlyImport: Bool = false
    weak var delegate: OnboardingManagerDelegate?
    /// Did the user just signed up through the onboarding
    var userDidSignUp: Bool = false
    var temporaryCredentials: (email: String, password: String)?

    var checkedEmail: (email: String, exists: Bool) = ("", false)

    private weak var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    init(onlyImport: Bool = false, analyticsCollector: AnalyticsCollector? = nil) {
        self.analyticsCollector = analyticsCollector

        let needsToDisplayOnboard = Configuration.env != .test && Configuration.env != .uiTest && Persistence.Authentication.hasSeenOnboarding != true
        var step: OnboardingStep?
        if needsToDisplayOnboard {
            step = OnboardingStep(type: .minimalWelcome)
//            if AuthenticationManager.shared.isAuthenticated {
//                if AuthenticationManager.shared.username != nil {
//                    step = OnboardingStep(type: .imports)
//                } else {
//                    step = OnboardingStep(type: .profile)
//                }
//            } else {
//                step = OnboardingStep(type: .welcome)
//            }
        }
        if onlyImport {
            step = OnboardingStep(type: .imports)
        }
        self.needsToDisplayOnboard = needsToDisplayOnboard
        currentStep = step ?? OnboardingStep(type: .welcome)
    }

    func resetOnboarding() {
        currentStep = OnboardingStep(type: .minimalWelcome)
        actions = []
        stepsHistory.removeAll()
        cancellables.removeAll()
        currentStepIsFromHistory = false
        viewIsLoading = false
        temporaryCredentials = nil
        userDidSignUp = false
        onlyConnect = false
        onlyImport = false
    }

    func forceDisplayOnboarding() {
        resetOnboarding()
        needsToDisplayOnboard = true
        Persistence.Authentication.hasSeenOnboarding = false
    }

    private func prepareForConnectOnly() {
        resetOnboarding()
        needsToDisplayOnboard = true
        onlyConnect = true
        currentStep = OnboardingStep(type: .welcome)
    }

    func showOnboardingForConnectOnly(withConfirmationAlert: Bool = false, message: String? = nil) {
        let presentBlock: () -> Void = {
            self.prepareForConnectOnly()
            self.presentOnboardingWindow()
        }
        if withConfirmationAlert {
            UserAlert.showAlert(message: loc("Connect to Beam"), informativeText: message ?? loc("Connect to Beam to sync, encrypt and publish your notes."),
                                buttonTitle: loc("Connect"), secondaryButtonTitle: loc("Cancel"), buttonAction: presentBlock)
        } else {
            presentBlock()
        }
    }

    func backToPreviousStep() {
        guard let previous = stepsHistory.popLast() else { return }
        if [.emailConnect, .welcome].contains(previous.type) {
            AppData.shared.currentAccount?.logoutIfNeeded()
        }
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
        case .welcome, .emailConnect, .emailConfirm:
            if AuthenticationManager.shared.isAuthenticated && !userHasUsername() {
                return OnboardingStep(type: .profile)
            }
            return stepAfterProfile()
        case .profile:
            return stepAfterProfile()
        case .savePrivateKey:
            return importStepIfNeeded(onlyConnect: onlyConnect)
        case .setupPrivateKey:
            return stepAfterProfile()
        case .imports, .loading, .lostPrivateKey, .setupCalendar:
            return nil
        case .minimalWelcome:
            return OnboardingStep(type: .setupCalendar)
        }
    }

    private func stepAfterProfile() -> OnboardingStep? {
        encryptionKeyStepIfNeeded() ?? importStepIfNeeded(onlyConnect: onlyConnect)
    }

    private func encryptionKeyStepIfNeeded() -> OnboardingStep? {
        if userDidSignUp {
            return OnboardingStep(type: .savePrivateKey)
        }
        return nil
    }

    private func importStepIfNeeded(onlyConnect: Bool) -> OnboardingStep? {
        if onlyConnect || userHasPasswordsData() {
            return nil
        } else {
            return OnboardingStep(type: .imports)
        }
    }

    private func onboardingDidStart() {

    }

    private func onboardingDidFinish() {
        let isNewUser = userDidSignUp || (!onlyConnect && !onlyImport)
        delegate?.onboardingManagerDidFinish(isNewUser: isNewUser)
        if isNewUser {
            onboardingNoteCreator.createOnboardingNotes(data: BeamData.shared)
        }
        Persistence.Authentication.hasSeenOnboarding = true
        resetOnboarding()
    }

    func userHasUsername() -> Bool {
        AuthenticationManager.shared.username != nil
    }

    private func userHasPasswordsData() -> Bool {
        BeamData.shared.passwordManager.count() > 0
    }

    func checkForPrivateKey(completionHandler: @escaping (OnboardingStep?) -> Void, syncCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        Task { @MainActor in
            if let currentAccount = AppData.shared.currentAccount {
                if await currentAccount.checkPrivateKey(useBuiltinPrivateKeyUI: false) {
                    completionHandler(nil)
                    currentAccount.runFirstSync(useBuiltinPrivateKeyUI: false) { result in
                        syncCompletion?(result)
                    }
                } else {
                    completionHandler(OnboardingStep(type: .setupPrivateKey))
                }
            } else {
                assert(false)
            }
        }
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
        guard onlyConnect || onlyImport else { return }
        resetOnboarding()
        needsToDisplayOnboard = false
    }
}
