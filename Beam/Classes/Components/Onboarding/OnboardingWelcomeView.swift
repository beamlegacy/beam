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
    var finish: OnboardingView.StepFinishCallback
    @State private var isLoadingDataStartTime: Date?

    private enum SigninError: Error {
        case googleFailed
    }
    @State private var error: SigninError?

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
                OnboardingView.TitleText(title: welcoming ? "Welcome to Beam" : "Connect to Beam")
                VStack(spacing: BeamSpacing._100) {
                    GoogleButton(buttonType: .signin, onClick: nil, onConnect: onSigninDone, onDataSync: onDataSyncDone, onFailure: onGoogleSigninError, label: { _ in
                        ActionableButton(text: "Continue with Google", defaultState: .normal, variant: googleVariant, minWidth: 280)
                    })
                    .buttonStyle(.borderless)
                    .overlay(error != .googleFailed ? nil : Tooltip(title: "Couldn't login with Google")
                                .fixedSize().offset(x: 0, y: -30).transition(.opacity.combined(with: .move(edge: .bottom))),
                             alignment: .top)
                    .animation(BeamAnimation.easeInOut(duration: 0.3), value: error)
                    ActionableButton(text: "Continue with Email", defaultState: .normal, variant: secondaryCenteredVariant, minWidth: 280) {
                        finish(OnboardingStep(type: .emailConnect))
                    }
                    Text("Sync and encrypt your notes")
                        .font(BeamFont.regular(size: 10).swiftUI)
                        .foregroundColor(BeamColor.AlphaGray.swiftUI)
                }
                if welcoming {
                    HStack {
                        Separator(horizontal: true)
                        Text("or")
                            .font(BeamFont.regular(size: 10).swiftUI)
                            .foregroundColor(BeamColor.AlphaGray.swiftUI)
                        Separator(horizontal: true)
                    }
                    ButtonLabel("Sign up later, alligator!", customStyle: .init(font: BeamFont.regular(size: 12).swiftUI, activeBackgroundColor: .clear, disableAnimations: false)) {
                        finish(nil)
                    }
                }
            }
        }
    }

    private func onGoogleSigninError() {
        guard error == nil else { return }
        error = .googleFailed
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
            error = nil
        }
    }

    private func onSigninDone() {
        guard AuthenticationManager.shared.isAuthenticated else { return }
        isLoadingDataStartTime = BeamDate.now
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
        OnboardingWelcomeView(welcoming: true) { _ in }
        OnboardingWelcomeView(welcoming: false) { _ in }

    }
}
