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
        case setupPrivateKey
        case lostPrivateKey
        case emailConfirm
        case imports
        case savePrivateKey
        case loading
    }

    let type: StepType
    var title: String?
}

protocol OnboardingManagerDelegate: AnyObject {
    func onboardingManagerDidFinish(userDidSignUp: Bool)
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
        var customWidth: CGFloat?
        /// return true to go to the next step
        var onClick: (() -> Bool)?
    }

    @Published private(set) var needsToDisplayOnboard: Bool
    @Published private(set) var currentStep: OnboardingStep
    @Published var actions = [StepAction]()
    @Published var viewIsLoading = false
    @Published private(set) var stepsHistory = [OnboardingStep]()

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

    init(onlyImport: Bool = false) {
        let needsToDisplayOnboard = Configuration.env != .test && Persistence.Authentication.hasSeenOnboarding != true
        var step: OnboardingStep?
        if needsToDisplayOnboard {
            if AuthenticationManager.shared.isAuthenticated {
                if AuthenticationManager.shared.username != nil {
                    step = OnboardingStep(type: .imports)
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
    }

    func resetOnboarding() {
        currentStep = OnboardingStep(type: .welcome)
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

    func prepareForConnectOnly() {
        resetOnboarding()
        needsToDisplayOnboard = true
        onlyConnect = true
    }

    func backToPreviousStep() {
        guard let previous = stepsHistory.popLast() else { return }
        if [.emailConnect, .welcome].contains(previous.type) {
            AccountManager.logoutIfNeeded()
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
            if AuthenticationManager.shared.isAuthenticated && AccountManager.state == .signedIn {
                stepsHistory.removeAll()
            } else {
                stepsHistory.append(previous)
            }
        } else {
            needsToDisplayOnboard = false
            dismissOnboardingWindow()
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
        case .imports, .loading, .lostPrivateKey:
            return nil
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
        AuthenticationManager.shared.isAuthenticatedPublisher.receive(on: DispatchQueue.main).sink { [weak self] isAuthenticated in
            if isAuthenticated && AccountManager.state == .signedIn {
                self?.stepsHistory.removeAll()
            }
        }.store(in: &cancellables)
    }

    private func onboardingDidFinish() {
        let userDidSignUp = userDidSignUp
        Persistence.Authentication.hasSeenOnboarding = true
        resetOnboarding()
        delegate?.onboardingManagerDidFinish(userDidSignUp: userDidSignUp)
        if userDidSignUp {
            OnboardingNoteCreator.shared.createOnboardingNotes()
        }
    }

    func userHasUsername() -> Bool {
        AuthenticationManager.shared.username != nil
    }

    private func userHasPasswordsData() -> Bool {
        PasswordManager.shared.count() > 0
    }

    func checkForPrivateKey(completionHandler: @escaping (OnboardingStep?) -> Void, syncCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        switch AccountManager.checkPrivateKey(useBuiltinPrivateKeyUI: false) {
        case .signedIn:
            completionHandler(nil)
            AccountManager().runFirstSync(useBuiltinPrivateKeyUI: false) { result in
                syncCompletion?(result)
            }
        case .privateKeyCheck:
            completionHandler(OnboardingStep(type: .setupPrivateKey))
        default:
            assert(false)
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
        return
    }

    func dismissOnboardingWindow() {
        window?.close()
        window = nil
        onboardingDidFinish()
    }

    func windowDidClose() {
        guard onlyConnect || onlyImport else { return }
        resetOnboarding()
        needsToDisplayOnboard = false
    }
}
