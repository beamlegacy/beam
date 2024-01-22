//
//  OnboardingEmailConnectView.swift
//  Beam
//
//  Created by Remi Santos on 12/11/2021.
//

import SwiftUI
import BeamCore

struct OnboardingEmailConnectView: View {
    @Binding var actions: [OnboardingManager.StepAction]
    var finish: OnboardingView.StepFinishCallback

    @EnvironmentObject private var onboardingManager: OnboardingManager
    @State private var emailField: String = ""
    @State private var passwordField: String = ""
    @State private var passwordVerificationField: String = ""
    @State private var isPasswordEditing: Bool = false
    @State private var isPasswordVerificationEditing: Bool = false

    @State private var areCredentialsValid: Bool = false
    @State private var forgotPasswordTooltip: LocalizedStringKey?

    private enum LoadingState: Equatable {
        case signinin
        case signinup
        case gettingInfos
    }
    @State private var loadingState: LoadingState?

    private enum ConnectError: Error, Equatable {
        case invalidCredentials
        case invalidEmail
        case genericError(description: String)
    }
    @State private var errorState: ConnectError?

    private enum PasswordRequirements {
        case length; case symbol; case number; case matches
    }
    @State private var passwordMissingRequirements: [PasswordRequirements] = [.length, .number, .symbol, .matches]

    private var errorMessage: String? {
        guard let errorState = errorState else { return nil }
        switch errorState {
        case .invalidCredentials:
            return "You have entered invalid credentials"
        case .invalidEmail:
            return "You have entered an invalid email address"
        case .genericError(let description):
            return description
        }
    }

    @State private var securePasswordField = true
    @State private var securePasswordVerificationField = true

    private func passwordField(secure: Bool, isVerify: Bool = false) -> some View {
        BeamTextField(text: isVerify ? $passwordVerificationField : $passwordField,
                      isEditing: isVerify ? $isPasswordVerificationEditing : $isPasswordEditing,
                      placeholder: isVerify ? "Verify Password" : "Password",
                      font: BeamFont.regular(size: 14).nsFont,
                      textColor: BeamColor.Generic.text.nsColor,
                      placeholderColor: BeamColor.Generic.placeholder.nsColor,
                      secure: secure,
                      contentType: isSignIn ? .password : nil,
                      onTextChanged: { newText in
            updateMissingRequirements(for: newText)
            updateButtonState()
        }, onCommit: { _ in
            validateForm()
        }, onTab: {
            isPasswordEditing.toggle()
            isPasswordVerificationEditing.toggle()
            return true
        })
            .frame(height: 40)
            .accessibility(identifier: "passwordField\(isVerify ? "Verify" : "")\(isPasswordEditing ? "-editing" : "")")
    }

    @ViewBuilder private var passwordZone: some View {
        HStack {
            // We can't just update the view because of how NSSecureTextField cannot "become" a NSTextField
            if securePasswordField {
                passwordField(secure: true)
            } else {
                passwordField(secure: false)
            }
            if isPasswordEditing, !passwordField.isEmpty {
                ButtonLabel(icon: securePasswordField ? "editor-password_show" : "editor-password_hide") {
                    securePasswordField.toggle()
                }
            }
        }
        Separator(horizontal: true, color: BeamColor.Nero)
        if !isSignIn {
            HStack {
                if securePasswordVerificationField {
                    passwordField(secure: true, isVerify: true)
                } else {
                    passwordField(secure: false, isVerify: true)
                }
                if isPasswordVerificationEditing, !passwordVerificationField.isEmpty {
                    ButtonLabel(icon: securePasswordVerificationField ? "editor-password_show" : "editor-password_hide") {
                        securePasswordVerificationField.toggle()
                    }
                }
            }
            Separator(horizontal: true, color: BeamColor.Nero)
        }
    }

    private var emailForm: some View {
        Group {
            VStack(alignment: .leading, spacing: BeamSpacing._120) {
                VStack(spacing: 0) {
                    Text(emailField)
                        .frame(width: 280, height: 40, alignment: .leading)
                        .font(BeamFont.regular(size: 14).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .accessibility(identifier: "emailField")
                    Separator(horizontal: true, color: BeamColor.Nero)
                    passwordZone
                }
                Group {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(BeamColor.Shiraz.swiftUI)
                    } else if !isSignIn && isPasswordEditing {
                        StyledText(verbatim: "Use at least 8 characters, 1 symbol and 1 number")
                            .style(.foregroundColor(BeamColor.Niobium.swiftUI))
                            .style(.foregroundColor(BeamColor.CharmedGreen.swiftUI), ranges: { passwordHelpRanges(in: $0, matchingRequirements: false) })
                    } else if !isSignIn, !passwordField.isEmpty, passwordField != passwordVerificationField {
                        Text("Make sure your passwords match").foregroundColor(BeamColor.Niobium.swiftUI)
                    } else {
                        Text("Preserve Height").hidden()
                    }
                }
                .font(BeamFont.regular(size: 11).swiftUI)
                .foregroundColor(BeamColor.AlphaGray.swiftUI)
            }
            .padding(.bottom, 24)
            .allowsHitTesting(loadingState == nil)
            if isSignIn {
                ButtonLabel("Forgot password", customStyle: .init(font: BeamFont.medium(size: 13).swiftUI, foregroundColor: BeamColor.Corduroy.swiftUI, activeBackgroundColor: .clear, disableAnimations: false)) {
                    sendForgotPassword()
                }
                .overlay(forgotPasswordTooltip == nil ? nil : Tooltip(title: forgotPasswordTooltip ?? "")
                            .fixedSize().offset(x: 0, y: 30).transition(.opacity.combined(with: .move(edge: .top))),
                         alignment: .bottom)
                .animation(BeamAnimation.easeInOut(duration: 0.3), value: forgotPasswordTooltip)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if loadingState == .gettingInfos {
                OnboardingView.LoadingView()
                    .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
            } else {
                VStack(spacing: 0) {
                    OnboardingView.TitleText(title: isSignIn ? "Sign In with Email" : "Sign Up with Email")
                    emailForm
                }
                .frame(width: 280)
                .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
            }
        }
        .onAppear {
            updateButtonState()
            emailField = onboardingManager.checkedEmail.email
            onboardingManager.userDidSignUp = false
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                // wait a little for the animation to finish before focusing the text field
                isPasswordEditing = true
            }
        }
    }

    private var isSignIn: Bool {
        return onboardingManager.checkedEmail.exists
    }

    private func updateMissingRequirements(for text: String) {
        guard !isSignIn else {
            passwordMissingRequirements = []
            return
        }

        var missing = [PasswordRequirements]()
        if passwordField.count < 8 {
            missing.append(.length)
        }
        if !passwordField.matches(withRegex: "[0-9]+") {
            missing.append(.number)
        }
        if !passwordField.matches(withRegex: "[^A-Za-z0-9]+") {
            missing.append(.symbol)
        }
        if !passwordField.isEmpty, passwordField != passwordVerificationField {
            missing.append(.matches)
        }
        passwordMissingRequirements = missing
    }

    private let actionId = "connect_button"
    private func updateButtonState() {
        forgotPasswordTooltip = nil
        errorState = nil
        areCredentialsValid = passwordMissingRequirements.isEmpty && emailField.mayBeEmail
        guard loadingState != .gettingInfos else {
            actions = []
            return
        }
        actions = [
            .init(id: actionId, title: isSignIn ? "Sign In" : "Sign Up", enabled: areCredentialsValid && loadingState == nil, onClick: {
                validateForm()
                return false
            })
        ]
    }

    private func validateForm() {
        if isSignIn {
            triggerConnect()
        } else {
            createAccount()
        }
    }

    private func triggerConnect() {
        guard areCredentialsValid, loadingState == nil else { return }
        isPasswordEditing = false
        loadingState = .signinin
        updateButtonState()
    }

    private func showEmailConfirmationStep() {
        onboardingManager.temporaryCredentials = (emailField, passwordField)
        // If the user is signing in, but is not yet validated, we should probably consider it as a signup
        onboardingManager.userDidSignUp = true
        finish(.init(type: .emailConfirm))
    }

    private func createAccount() {
        guard areCredentialsValid, loadingState == nil else { return }
        loadingState = .signinup
    }

    private func handleSyncCompletion(startTime: Date) {
        let delay = Int(max(0, (2 + startTime.timeIntervalSinceNow).rounded(.up)))
        // leave some time on the loading view for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
            finish(nil)
        }
    }

    private func sendForgotPassword() {
        let email = emailField
        guard email.mayBeEmail, forgotPasswordTooltip == nil else {
            errorState = .invalidEmail
            return
        }
    }

    private func passwordHelpRanges(in text: String, matchingRequirements: Bool) -> [Range<String.Index>] {
        var result = [Range<String.Index>]()
        if passwordMissingRequirements.contains(.length) == matchingRequirements {
            result.append(contentsOf: text.ranges(of: "8 characters"))
        }
        if passwordMissingRequirements.contains(.symbol) == matchingRequirements {
            result.append(contentsOf: text.ranges(of: "1 symbol"))
        }
        if passwordMissingRequirements.contains(.number) == matchingRequirements {
            result.append(contentsOf: text.ranges(of: "1 number"))
        }
        return result
    }
}

struct OnboardingEmailConnectView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingEmailConnectView(actions: .constant([]), finish: { _ in })
            .padding(20)
            .background(BeamColor.Generic.background.swiftUI)
    }
}
