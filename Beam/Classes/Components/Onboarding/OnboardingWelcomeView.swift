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

    @State private var email: String = ""
    @State private var isEditingEmail: Bool = false

    private var secondaryCenteredVariant: ActionableButtonVariant {
        var style = ActionableButtonVariant.secondary.style
        style.icon = nil
        style.textAlignment = .center
        return .custom(style)
    }

    var body: some View {
        VStack(spacing: BeamSpacing._200) {
            VStack(spacing: BeamSpacing._140) {
                AppIcon()
                    .frame(width: 64, height: 64)
                OnboardingView.TitleText(title: welcoming ? "Welcome to Beam" : "Set up Beam")
            }
            VStack(spacing: 14) {
                BeamTextField(text: $email, isEditing: $isEditingEmail, placeholder: "Enter your email address", font: BeamFont.regular(size: 14).nsFont,
                              textColor: BeamColor.Generic.text.nsColor, placeholderColor: BeamColor.LightStoneGray.nsColor, onCommit: { _ in
                    continueWithEmail()
                }).accessibilityIdentifier("emailField")
                    .frame(width: 280, height: 40)
                    .overlay(Separator(horizontal: true), alignment: .bottom)
                ActionableButton(text: "Continue", defaultState: continueButtonEnabled ? .normal : .disabled, variant: secondaryCenteredVariant, minWidth: 280, height: 34) {
                    continueWithEmail()
                }
                .opacity(email.isEmpty ? 0.0 : 1.0)
                .animation(BeamAnimation.easeInOut(duration: 0.4), value: email.isEmpty)
                .accessibilityHidden(email.isEmpty)
                .accessibility(identifier: continueButtonEnabled ? "continue-with-email" : "continue-with-email-disabled")
            }
            if welcoming {
                ButtonLabel("Skip", customStyle: .init(font: BeamFont.regular(size: 13).swiftUI, foregroundColor: BeamColor.Corduroy.swiftUI, activeBackgroundColor: .clear, disableAnimations: false)) {
                    onboardingManager.onboardingNoteCreator.createOnboardingNotes(data: BeamData.shared)
                    finish(nil)
                }
            }
        }
        .onAppear {
            email = onboardingManager.checkedEmail.email
        }
    }

    private var continueButtonEnabled: Bool {
        email.mayBeEmail
    }

    private func continueWithEmail() {
        guard !email.isEmpty, email.mayBeEmail else { return }
        onboardingManager.checkedEmail = (email, false)
        finish(nil)
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
