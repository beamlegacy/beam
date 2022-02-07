//
//  OnboardingEmailConfirmationView.swift
//  Beam
//
//  Created by Remi Santos on 05/01/2022.
//

import SwiftUI
import BeamCore

struct OnboardingEmailConfirmationView: View {
    @Binding var actions: [OnboardingManager.StepAction]
    var finish: OnboardingView.StepFinishCallback

    @EnvironmentObject private var onboardingManager: OnboardingManager
    @State private var email: String = "..."
    @State private var password: String = ""

    @State private var emailConfirmationTooltip: String?

    private enum LoadingState: Equatable {
        case signinin
        case gettingInfos
    }
    @State private var loadingState: LoadingState?

    private enum ConnectError: Error, Equatable {
        case notConfirmed
        case genericError(description: String)
    }
    @State private var errorState: ConnectError?

    private let accountManager = AccountManager()
    private var buttonVariant: ActionableButtonVariant {
        var style = ActionableButtonVariant.gradient(icon: nil).style
        style.textAlignment = .center
        return .custom(style)
    }

    private var errorMessage: String? {
        guard let errorState = errorState else { return nil }
        switch errorState {
        case .notConfirmed:
            return "You must confirm your email first."
        case .genericError(let description):
            return description
        }
    }

    private var text: String {
        """
        A confirmation email was sent to: \(email).

        Follow the instructions to confirm your account.
        """
    }

    private func highlightedTextRanges(in text: String) -> [Range<String.Index>] {
        text.ranges(of: email)
    }

    var body: some View {
        VStack(spacing: 0) {
            if loadingState == .gettingInfos {
                OnboardingView.LoadingView()
                    .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
            } else {
                VStack(spacing: 0) {
                    OnboardingView.TitleText(title: "Check your inbox!")
                    VStack(spacing: BeamSpacing._400) {
                        VStack(alignment: .leading, spacing: BeamSpacing._100) {
                            StyledText(verbatim: text)
                                .style(.font(BeamFont.semibold(size: 14).swiftUI), ranges: highlightedTextRanges)
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(BeamColor.Shiraz.swiftUI)
                            }
                        }
                        .font(BeamFont.regular(size: 14).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)

                    ButtonLabel("Send Confirmation Email Again", customStyle: .init(font: BeamFont.medium(size: 13).swiftUI, activeBackgroundColor: .clear, disableAnimations: false)) {
                        resendEmailConfirmation()
                    }
                    .overlay(emailConfirmationTooltip == nil ? nil : Tooltip(title: emailConfirmationTooltip ?? "")
                                .fixedSize().offset(x: 0, y: 30).transition(.opacity.combined(with: .move(edge: .top))),
                             alignment: .bottom)
                    .animation(BeamAnimation.easeInOut(duration: 0.3), value: emailConfirmationTooltip)
                    }
                }
                .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)))
            }
        }
        .frame(maxWidth: 280)
        .background(KeyEventHandlingView(handledKeyCodes: [.enter], firstResponder: true, onKeyDown: { _ in
            triggerConnect()
        }))
        .onAppear {
            updateActions()
            if let tmpCredentials = onboardingManager.temporaryCredentials {
                email = tmpCredentials.email
                password = tmpCredentials.password
            }
        }
    }

    private let actionId = "email_confirm_continue"
    private func updateActions() {
        if loadingState != nil {
            actions = []
        } else {
            actions = [
                .init(id: actionId, title: "Continue", enabled: loadingState == nil, onClick: {
                    triggerConnect()
                    return false
                })
            ]
        }
    }
    private func triggerConnect() {
        guard loadingState == nil else { return }
        errorState = nil
        loadingState = .signinin
        updateActions()
        var loadingStartTime = BeamDate.now
        accountManager.signIn(email: email, password: password) { result in
            DispatchQueue.main.async {
                updateActions()
                switch result {
                case .failure(let error):
                    loadingState = nil
                    if error as? APIRequestError != nil {
                        errorState = .notConfirmed
                    } else {
                        errorState = .genericError(description: error.localizedDescription)
                    }
                    updateActions()
                case .success:
                    Logger.shared.logInfo("Sign in after email confirmation succeeded", category: .network)
                    loadingState = .gettingInfos
                    loadingStartTime = BeamDate.now
                }
            }
        } syncCompletion: { _ in
            handleSyncCompletion(startTime: loadingStartTime)
        }
    }

    private func handleSyncCompletion(startTime: Date) {
        let delay = Int(max(0, (2 + startTime.timeIntervalSinceNow).rounded(.up)))
        // leave some time on the loading view for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
            finish(nil)
        }
    }

    private func resendEmailConfirmation() {
        guard emailConfirmationTooltip == nil else {
            return
        }
        errorState = nil
        accountManager.resendVerificationEmail(email: email) { result in
            switch result {
            case .failure(let error):
                emailConfirmationTooltip = error.localizedDescription
            case .success:
                emailConfirmationTooltip = "Another confirmation email has been sent"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                emailConfirmationTooltip = nil
            }
        }
    }
}

struct OnboardingEmailConfirmationView_Previews: PreviewProvider {
    static var onboardingManager: OnboardingManager {
        let mngr = OnboardingManager()
        mngr.temporaryCredentials = ("tyler_joseph@beamapp.co", "nothing")
        return mngr
    }
    static var previews: some View {
        OnboardingEmailConfirmationView(actions: .constant([]), finish: { _ in })
            .environmentObject(onboardingManager)
            .padding(20)
            .frame(width: 400, height: 400)
            .background(BeamColor.Generic.background.swiftUI)
    }
}
