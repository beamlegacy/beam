//
//  OnboardingView.swift
//  Beam
//
//  Created by Remi Santos on 09/11/2021.
//

import SwiftUI
import Combine

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
    private let estimatedSafeAreaInsets = NSEdgeInsets(top: 38, left: 0, bottom: 0, right: 0) // invisible toolbar

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer(minLength: 100)
                Group {
                    let finishCallback: StepFinishCallback = { nextStep in
                        model.advanceToNextStep(nextStep)
                    }
                    switch currentStep.type {
                    case .profile:
                        OnboardingProfileCreationView(actions: $model.actions, finish: finishCallback)
                    case .emailConnect:
                        OnboardingEmailConnectView(actions: $model.actions, finish: finishCallback)
                    case .emailConfirm:
                        OnboardingEmailConfirmationView(actions: $model.actions, finish: finishCallback)
                    case .imports:
                        OnboardingImportsView(actions: $model.actions, finish: finishCallback)
                    case .saveEncryption:
                        OnboardingSaveEncryptionView(actions: $model.actions, finish: finishCallback)
                    default:
                        OnboardingWelcomeView(welcoming: !model.onlyConnect, viewIsLoading: $model.viewIsLoading, finish: finishCallback)
                    }
                }
                .offset(x: 0, y: stepOffset[currentStep.type] ?? 0)
                .opacity(stepOpacity[currentStep.type] ?? 1)
                Spacer(minLength: 0)
            }
            .frame(minWidth: 280)
            .padding(.top, BeamSpacing._100)
            .fixedSize(horizontal: true, vertical: false)
            .environmentObject(model)
            bottomBar
        }
        .background(BeamColor.Generic.background.swiftUI.edgesIgnoringSafeArea(.all))
        .frame(width: 512, height: 600 - estimatedSafeAreaInsets.top)
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

    private let bottomBarHeight: CGFloat = 94
    private let buttonsHeight: CGFloat = 34
    private var secondarActionVariant: ActionableButtonVariant {
        var style = ActionableButtonVariant.secondary.style
        style.icon = .init(name: "shortcut-bttn_space", size: 16, palette: style.icon?.palette, alignment: .trailing)
        return .custom(style)
    }

    private struct TextLink: View {
        var text: String
        var action: () -> Void
        @State private var isHovering = false
        var body: some View {
            Text(text)
                .foregroundColor((isHovering ? BeamColor.Corduroy : BeamColor.AlphaGray).swiftUI)
                .onTapGesture(perform: action)
                .onHover { isHovering = $0 }
        }
    }

    private var bottomBar: some View {
        ZStack(alignment: .bottom) {
            if !model.viewIsLoading && [.welcome].contains(currentStep.type) {
                HStack(spacing: 0) {
                    TextLink(text: "Terms and Conditions") {
                        openExternalURL(Configuration.beamTermsConditionsLink, title: "Terms and Conditions")
                    }
                    Text(" • ")
                    TextLink(text: "Privacy Policy") {
                        openExternalURL(Configuration.beamPrivacyPolicyLink, title: "Privacy Policy")
                    }
                }
                .font(BeamFont.medium(size: 11).swiftUI)
                .foregroundColor(BeamColor.AlphaGray.swiftUI)
                .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.15)))
                .padding(.bottom, 30)
            }
            HStack(spacing: 0) {
                if model.stepsHistory.count > 0 {
                    BackButton()
                        .onTapGesture {
                            model.backToPreviousStep()
                        }
                        .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.15).delay(0.2)))
                }
                Spacer()
                HStack(spacing: BeamSpacing._200) {
                    ForEach(model.actions) { action in
                        ActionableButton(text: action.title, defaultState: !action.enabled ? .disabled : .normal,
                                         variant: action.secondary ? secondarActionVariant : .primaryPurple,
                                         minWidth: action.secondary ? 100 : 150,
                                         height: buttonsHeight,
                                         action: !action.enabled ? nil : {
                            if action.onClick?() != false {
                                model.advanceToNextStep()
                            }
                        })
                            .disabled(!action.enabled)
                            .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.15).delay(0.2)))
                            .accessibilityIdentifier(action.id)
                    }
                }
            }
            .frame(height: buttonsHeight)
            .padding([.trailing, .bottom], BeamSpacing._400)
            .padding(.leading, 30)
        }
        .animation(BeamAnimation.easeInOut(duration: 0.15), value: model.actions)
        .frame(maxWidth: .infinity)
        .frame(height: bottomBarHeight, alignment: .bottom)
    }

    private func openExternalURL(_ urlString: String, title: String) {
        guard let url = URL(string: urlString) else { return }
        AppDelegate.main.openMinimalistWebWindow(url: url, title: title)
    }

    struct TitleText: View {
        var title: String
        var body: some View {
            Text(title)
                .font(BeamFont.medium(size: 24).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .padding(.bottom, 40)
        }
    }

    struct LoadingView: View {
        var message: String = "Setting up your beam"
        private var subtitle: String {
            "Syncing \(detailToDisplay)"
        }
        private let defaultDetails = [
            "account", "notes", "images", "embeds"
        ]
        var syncingDetails: [String]?
        private var randomDetails: [String] {
            syncingDetails ?? defaultDetails
        }

        @State private var detailToDisplay = ""
        @State private var detailLoopCancellable: Cancellable?

        var body: some View {
            VStack(spacing: BeamSpacing._140) {
                Image("preferences-about-beam-beta")
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(spacing: BeamSpacing._100) {
                    Text(message)
                        .font(BeamFont.medium(size: 24).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                    HStack(spacing: BeamSpacing._40) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: BeamColor.LightStoneGray.swiftUI))
                            .scaleEffect(0.5, anchor: .center)
                            .frame(width: 16, height: 16)
                        Text(subtitle)
                            .font(BeamFont.regular(size: 14).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    }
                }
            }
            .onAppear {
                if let first = randomDetails.first {
                    detailToDisplay = first
                }
                detailLoopCancellable = Timer.publish(every: 3, on: .main, in: .common).autoconnect().sink(receiveValue: { _ in
                    var newDetail = randomDetails.randomElement()
                    while newDetail == detailToDisplay {
                        newDetail = randomDetails.randomElement()
                    }
                    guard let newDetail = newDetail else { return }

                    detailToDisplay = newDetail
                })
            }
            .onDisappear {
                detailLoopCancellable?.cancel()
            }
        }
    }

    struct BackButton: View {
        @State private var isHovering = false
        private var foregroundColor: Color {
            (isHovering ? BeamColor.Niobium : BeamColor.AlphaGray).swiftUI
        }
        var body: some View {
            HStack(spacing: 1) {
                Icon(name: "nav-back", size: CGSize(width: 20, height: 24), color: foregroundColor)
                Text("Back")
                    .foregroundColor(foregroundColor)
                    .font(BeamFont.regular(size: 14).swiftUI)
            }
            .onHover { isHovering = $0 }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {

    static var onboardingManager: OnboardingManager {
        let mngr = OnboardingManager()
        mngr.advanceToNextStep(.init(type: .welcome))
        return mngr
    }
    static var previews: some View {
        Group {
            OnboardingView(model: onboardingManager)
                .background(BeamColor.Generic.background.swiftUI)
        }

    }
}
