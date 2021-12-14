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
    private let actionId = UUID()

    private var subtitle: String {
        if let errorMessage = errorMessage {
            return errorMessage
        }
        var text = "Enter a username for your profile."
        if isAuthenticated && !textField.isEmpty {
            text += "\nYou can access your profile at beamapp.co/\(textField)"
        }
        return text
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingView.TitleText(title: "Create your profile")
            VStack(alignment: .leading, spacing: BeamSpacing._60) {
                BeamTextField(text: $textField, isEditing: $isEditing, placeholder: "Username", font: BeamFont.regular(size: 13).nsFont, textColor: BeamColor.Generic.text.nsColor, onTextChanged: { newValue in
                    errorMessage = nil
                    actions = [
                        .init(id: actionId, title: "Continue", enabled: isUsernameValid(newValue), onClick: {
                            saveUsernameAndFinish()
                            return false
                        })
                    ]
                }, onCommit: { _ in
                    saveUsernameAndFinish()
                })
                Text(subtitle)
                    .font(BeamFont.regular(size: 10).swiftUI)
                    .foregroundColor(errorMessage != nil ? BeamColor.Shiraz.swiftUI : BeamColor.Generic.subtitle.swiftUI)
            }
            .frame(width: 280)
            .frame(minHeight: 50, alignment: .top)
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
        username.count >= 4
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
    }
}
