//
//  OnboardingProfileCreationView.swift
//  Beam
//
//  Created by Remi Santos on 12/11/2021.
//

import SwiftUI
import BeamCore

struct OnboardingProfileCreationView: View {

    @Binding var actions: [OnboardingManager.StepAction]
    var finish: OnboardingView.StepFinishCallback
    @State private var textField: String = ""
    @State private var isEditing: Bool = true
    @State private var isAuthenticated: Bool = false
    @State private var errorMessage: String?
    private let actionId = "profile_continue"

    private var subtitle: String {
        if let errorMessage = errorMessage {
            return errorMessage
        }
        var text = "Choose your username"
        if textField.count >= 2 {
            text += "\nYou can access your profile at beamapp.co/\(textField)"
        }
        return text
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingView.TitleText(title: "Create your profile")
            VStack(alignment: .leading, spacing: BeamSpacing._120) {
                VStack(spacing: 0) {
                    BeamTextField(text: $textField, isEditing: $isEditing, placeholder: "Username", font: BeamFont.regular(size: 14).nsFont,
                                  textColor: BeamColor.Generic.text.nsColor, placeholderColor: BeamColor.Generic.placeholder.nsColor,
                                  onTextChanged: { newValue in
                        let isValid = isUsernameValid(newValue)
                        if !isValid {
                            errorMessage = buildErrorMessageForInvalidUsername(newValue)
                        } else {
                            errorMessage = nil
                        }
                        actions = [
                            .init(id: actionId, title: "Continue", enabled: isValid, onClick: {
                                saveUsernameAndFinish()
                                return false
                            })
                        ]
                    }, onCommit: { _ in
                        saveUsernameAndFinish()
                    })
                        .frame(height: 40)
                    Separator(horizontal: true, color: BeamColor.Nero)
                }

                Text(subtitle)
                    .font(BeamFont.regular(size: 12).swiftUI)
                    .lineLimit(3)
                    .foregroundColor(errorMessage != nil ? BeamColor.Shiraz.swiftUI : BeamColor.Generic.placeholder.swiftUI)
                    .frame(minHeight: 80, alignment: .top)
            }
            .frame(width: 280)
        }
        .onAppear {
            if let username = AuthenticationManager.shared.username {
                textField = username
            }
            isAuthenticated = AuthenticationManager.shared.isAuthenticated
            actions = [
                .init(id: actionId, title: "Continue", enabled: false)
            ]
        }
    }

    private func isUsernameValid(_ username: String) -> Bool {
        username.mayBeUsername
    }

    private func buildErrorMessageForInvalidUsername(_ username: String) -> String? {
        guard username.count >= 2 else { return nil }
        if username.count > 30 {
            return "Username is too long."
        }
        if !username.matches(withRegex: "^[A-Za-z0-9\\-_]+$") {
            return "Username can only include latin letters, numbers, dashes and underscores."
        }
        return nil
    }

    private func saveUsernameAndFinish() {
        let username = textField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isUsernameValid(username) else { return }
        let accountManager = AccountManager()
        accountManager.setUsername(username: username) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    if case APIRequestError.apiErrors(let errorable) = error, let firstError = errorable.errors?.first {
                        errorMessage = firstError.message
                    } else {
                        errorMessage = error.localizedDescription
                    }
                case .success:
                    finish(nil)
                }
            }
        }
    }
}

struct OnboardingProfileCreationView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingProfileCreationView(actions: .constant([])) { _ in }
        .padding(20)
        .background(BeamColor.Generic.background.swiftUI)
    }
}
