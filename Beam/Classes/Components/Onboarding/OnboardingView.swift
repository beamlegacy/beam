//
//  OnboardingView.swift
//  Beam
//
//  Created by Remi Santos on 09/11/2021.
//

import SwiftUI

struct OnboardingView: View {

    @ObservedObject var model: OnboardingManager

    typealias StepFinishCallback = (OnboardingStep?) -> Void

    // to fully control transitions, we use an internal state property for the current step
    @State private var displayedStep: OnboardingStep?
    var currentStep: OnboardingStep {
        displayedStep ?? model.currentStep
    }
    @State private var stepOffset: [OnboardingStep.StepType: CGFloat] = [:]
    @State private var stepOpacity: [OnboardingStep.StepType: CGFloat] = [:]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                switch currentStep.type {
                case .profile:
                    OnboardingProfileCreationView(actions: $model.actions) { nextStep in
                        model.advanceToNextStep(nextStep)
                    }
                    .offset(x: 0, y: stepOffset[.profile] ?? 0)
                    .opacity(stepOpacity[.profile] ?? 1)
                case .emailConnect:
                    OnboardingEmailConnectView { nextStep in
                        model.advanceToNextStep(nextStep)
                    }
                    .offset(x: 0, y: stepOffset[.emailConnect] ?? 0)
                    .opacity(stepOpacity[.emailConnect] ?? 1)
                case .imports:
                    OnboardingImportsView(actions: $model.actions) { nextStep in
                        model.advanceToNextStep(nextStep)
                    }
                        .offset(x: 0, y: stepOffset[.imports] ?? 0)
                        .opacity(stepOpacity[.imports] ?? 1)
                default:
                    OnboardingWelcomeView(welcoming: !model.onlyLogin) { nextStep in
                        model.advanceToNextStep(nextStep)
                    }
                    .offset(x: 0, y: stepOffset[.welcome] ?? 0)
                    .opacity(stepOpacity[.welcome] ?? 1)
                }
                Spacer(minLength: 0)
            }
            .frame(minWidth: 280)
            .padding(.top, BeamSpacing._100)
            .fixedSize(horizontal: true, vertical: false)
            bottomBar
        }
        .onAppear {
            displayedStep = model.currentStep
        }
        .onChange(of: model.currentStep) { newValue in
            guard newValue != displayedStep else { return }
            guard let displayedStep = displayedStep else {
                self.displayedStep = newValue
                return
            }
            animateStepTransition(to: newValue, from: displayedStep, reverse: model.currentStepIsFromHistory)
        }
    }

    private func animateStepTransition(to newStep: OnboardingStep, from previousStep: OnboardingStep, reverse: Bool = false) {
        let previousType = previousStep.type
        let newType = newStep.type
        stepOffset[newType] = reverse ? -40 : 40
        stepOpacity[newType] = 0

        // animate disappear previous step
        withAnimation(BeamAnimation.easeInOut(duration: 0.2)) {
            stepOpacity[previousType] = 0
        }
        withAnimation(BeamAnimation.defaultiOSEasing(duration: 0.3)) {
            stepOffset[previousType] = reverse ? 40 : -40
        }

        // animate appear new step after 0.2s
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
            self.displayedStep = newStep
            withAnimation(BeamAnimation.easeInOut(duration: 0.2)) {
                stepOpacity[newType] = 1
            }
            withAnimation(BeamAnimation.easeInOut(duration: 0.3)) {
                stepOffset[newType] = 0
            }
        }
    }

    private let customButtonStyle = ButtonLabelStyle(font: BeamFont.regular(size: 10).swiftUI, activeBackgroundColor: .clear)
    private let bottomBarHeight: CGFloat = 76
    private var secondarActionVariant: ActionableButtonVariant {
        var style = ActionableButtonVariant.secondary.style
        style.icon = .init(name: "shortcut-bttn_space", size: 16, palette: style.icon?.palette, alignment: .trailing)
        return .custom(style)
    }
    private var bottomBar: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                if model.stepsHistory.count > 0 {
                    ButtonLabel(nil, icon: "onboarding-back", customStyle: customButtonStyle) {
                        model.backToPreviousStep()
                    }
                    .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.3)))
                }
                Spacer()
                if [.welcome, .emailConnect].contains(currentStep.type) {
                    GlobalCenteringContainer(containerGeometry: proxy) {
                        HStack(spacing: 0) {
                            Text("Terms and Conditions").onTapGesture {
                                openExternalURL(Configuration.beamTermsConditionsLink, title: "Terms and Conditions")
                            }
                            Text(" • ")
                            Text("Privacy Policy").onTapGesture {
                                openExternalURL(Configuration.beamPrivacyPolicyLink, title: "Privacy Policy")
                            }
                        }
                    }
                    .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.3)))
                }
                Spacer()
                HStack(spacing: BeamSpacing._200) {
                    ForEach(model.actions) { action in
                        ActionableButton(text: action.title, defaultState: !action.enabled ? .disabled : .normal,
                                         variant: action.secondary ? secondarActionVariant : .gradient(icon: "shortcut-return"),
                                         minWidth: action.secondary ? 110 : 146,
                                         action: !action.enabled ? nil : {
                            if action.onClick?() != false {
                                model.advanceToNextStep()
                            }
                        })
                    }
                }
            }
            .font(BeamFont.medium(size: 10).swiftUI)
            .foregroundColor(BeamColor.AlphaGray.swiftUI)
            .padding(.horizontal, BeamSpacing._400)
            .frame(maxHeight: .infinity)
        }
        .animation(BeamAnimation.easeInOut(duration: 0.3), value: model.actions)
        .frame(height: bottomBarHeight)
        .frame(maxWidth: .infinity)
    }

    private func openExternalURL(_ urlString: String, title: String) {
        guard let url = URL(string: urlString) else { return }
        AppDelegate.main.openMinimalistWebWindow(url: url, title: title)
    }

    struct TitleText: View {
        var title: String
        var body: some View {
            Text(title)
                .font(BeamFont.medium(size: 20).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .padding(.bottom, 34)
        }
    }

    struct LoadingView: View {
        var message: String = "Importing your data..."
        var body: some View {
            VStack(spacing: BeamSpacing._200) {
                Rectangle()
                    .fill(BeamColor.Mercury.swiftUI)
                    .frame(width: 175, height: 128)
                    .cornerRadius(10)
                Text(message)
                    .font(BeamFont.medium(size: 17).swiftUI)
                    .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingView(model: OnboardingManager())
                .frame(width: 800, height: 512)
                .background(BeamColor.Generic.background.swiftUI)
        }

    }
}
