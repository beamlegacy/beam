//
//  OnboardingWelcomeView.swift
//  Beam
//
//  Created by Remi Santos on 12/11/2021.
//

import SwiftUI
import BeamCore

struct OnboardingWelcomeView: View {
    var welcoming: Bool
    @Binding var viewIsLoading: Bool
    var finish: OnboardingView.StepFinishCallback
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @State private var isLoadingDataStartTime: Date?

    @State private var email: String = ""
    @State private var isEditingEmail: Bool = false
    @State private var isCheckingForEmail: Bool = false

    private enum SigninError: Error {
        case googleFailed
        case checkEmailFailed
    }
    @State private var error: SigninError?
    private let userSessionRequest = UserSessionRequest()

    private var secondaryCenteredVariant: ActionableButtonVariant {
        var style = ActionableButtonVariant.secondary.style
        style.icon = nil
        style.textAlignment = .center
        return .custom(style)
    }
    private var googleVariant: ActionableButtonVariant {
        var style = ActionableButtonVariant.gradient(icon: "google-super-g").style
        var icon = style.icon
        icon?.alignment = .leading
        style.icon = icon
        style.textAlignment = .center
        return .custom(style)
    }
    var body: some View {
        VStack(spacing: BeamSpacing._200) {
            if isLoadingDataStartTime != nil {
                OnboardingView.LoadingView()
                    .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
            } else {
                VStack(spacing: BeamSpacing._140) {
                    AppIcon()
                        .frame(width: 64, height: 64)
                    OnboardingView.TitleText(title: welcoming ? "Welcome to Beam" : "Connect to Beam")
                }
                VStack(spacing: BeamSpacing._200) {
                    GoogleButton(buttonType: .signin, onClick: nil, onConnect: onSigninDone, onDataSync: nil, onFailure: onGoogleSigninError, label: { _ in
                        ActionableButton(text: "Continue with Google", defaultState: .normal, variant: googleVariant, minWidth: 280, height: 34)
                    })
                    .buttonStyle(.borderless)
                    .overlay(error != .googleFailed ? nil : Tooltip(title: "Couldn't login with Google")
                                .fixedSize().offset(x: 0, y: -30).transition(.opacity.combined(with: .move(edge: .bottom))),
                             alignment: .top)
                    .animation(BeamAnimation.easeInOut(duration: 0.3), value: error)
                    Text("or")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    VStack(spacing: 14) {
                        BeamTextField(text: $email, isEditing: $isEditingEmail, placeholder: "Sign Up/In with email address", font: BeamFont.regular(size: 14).nsFont,
                                      textColor: BeamColor.Generic.text.nsColor, placeholderColor: BeamColor.Generic.placeholder.nsColor, onCommit: { _ in
                            checkAccountExistence()
                        }).accessibilityIdentifier("emailField")
                            .frame(width: 280, height: 40)
                            .overlay(checkAccountProgressView, alignment: .trailing)
                        .overlay(Separator(horizontal: true), alignment: .bottom)
                        ActionableButton(text: "Continue with Email", defaultState: continueWithEmailButtonEnabled ? .normal : .disabled, variant: secondaryCenteredVariant, minWidth: 280, height: 34) {
                            self.checkAccountExistence()
                        }
                        .opacity(email.isEmpty ? 0.0 : 1.0)
                        .animation(BeamAnimation.easeInOut(duration: 0.4), value: email.isEmpty)
                        .accessibilityHidden(email.isEmpty)
                        .accessibility(identifier: continueWithEmailButtonEnabled ? "continue-with-email" : "continue-with-email-disabled")
                        .overlay(error != .checkEmailFailed ? nil : Tooltip(title: "Couldn't check email")
                                    .fixedSize().offset(x: 0, y: -30).transition(.opacity.combined(with: .move(edge: .bottom))),
                                 alignment: .top)
                        .animation(BeamAnimation.easeInOut(duration: 0.3), value: error)
                    }
                }
                if welcoming {
                    ButtonLabel("Sign Up/In Later", customStyle: .init(font: BeamFont.regular(size: 13).swiftUI, activeBackgroundColor: .clear, disableAnimations: false)) {
                        OnboardingNoteCreator.shared.createOnboardingNotes()
                        finish(nil)
                    }
                }
            }
        }
        .onAppear {
            email = onboardingManager.checkedEmail.email
        }
    }

    private var continueWithEmailButtonEnabled: Bool {
        email.mayBeEmail && !isCheckingForEmail
    }

    private func checkAccountExistence() {
        guard !email.isEmpty, email.mayBeEmail else { return }
        isCheckingForEmail = true
        _ = try? userSessionRequest.accountExists(email: email) { result in
            DispatchQueue.main.async {
                isCheckingForEmail = false
                switch result {
                case .success(let response):
                    onboardingManager.checkedEmail = (email, response.exists)
                    finish(OnboardingStep(type: .emailConnect))
                case .failure:
                    guard error == nil else { return }
                    error = .checkEmailFailed
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                        error = nil
                    }
                }
            }
        }
    }

    private var checkAccountProgressView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: BeamColor.LightStoneGray.swiftUI))
            .scaleEffect(0.5, anchor: .center)
            .frame(width: 16, height: 16)
            .opacity(isCheckingForEmail ? 1.0 : 0.0)
    }

    private func onGoogleSigninError() {
        guard error == nil else { return }
        error = .googleFailed
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
            error = nil
        }
        AccountManager.logoutIfNeeded()
    }

    private func onSigninDone() {
        DispatchQueue.main.async {
            guard AuthenticationManager.shared.isAuthenticated else { return }
            if let pkStatus = try? PrivateKeySignatureManager.shared.distantKeyStatus(), pkStatus == .none {
                // We do this to show the saveEncyptionView, user probably register his account with Google
                onboardingManager.userDidSignUp = true
            }

            self.onboardingManager.checkForPrivateKey { nextStep in
                guard nextStep != nil else {
                    self.viewIsLoading = true
                    self.isLoadingDataStartTime = BeamDate.now
                    return
                }
                finish(nextStep)
            } syncCompletion: { result in
                switch result {
                case .success:
                    onDataSyncDone()
                default:
                    Logger.shared.logError("Run first Sync failed when trying to connect with Google", category: .network)
                }
            }
        }
    }

    private func onDataSyncDone() {
        guard let startTime = isLoadingDataStartTime else { return }
        let delay = Int(max(0, (2 + startTime.timeIntervalSinceNow).rounded(.up)))
        // leave some time on the loading view for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
            finish(nil)
        }
    }
}

struct OnboardingWelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingWelcomeView(welcoming: true, viewIsLoading: .constant(false)) { _ in }
        .frame(width: 600, height: 600)
        .background(BeamColor.Generic.background.swiftUI)
        OnboardingWelcomeView(welcoming: false, viewIsLoading: .constant(false)) { _ in }
        .frame(width: 600, height: 600)
        .background(BeamColor.Generic.background.swiftUI)
    }
}
