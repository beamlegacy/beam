import Foundation
import SwiftUI
import BeamCore
import OAuthSwift

struct OauthButton: View {
    var type: IdentityRequest.Provider
    var authClient: OAuth2Swift
    var callbackURL: String
    var scope: String
    var buttonType: ButtonType = .connect

    var onClick: (() -> Void)?
    var onConnect: (() -> Void)?
    var onFailure: (() -> Void)?

    enum ButtonType {
        case connect
        case signin
    }

    private var buttonText: String {
        switch buttonType {
        case .connect: return "Connect \(type.rawValue.capitalized)..."
        case .signin: return "Sign In With \(type.rawValue.capitalized)..."
        }
    }

    // TODO: loc
    var body: some View {
        Button(action: {
            onClick?()

            connect()
        }, label: {
            Text(buttonText)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .frame(width: buttonType == .connect ? 126 : 145)
        })
    }

    private func connect() {
        let window = AppDelegate.main.openOauthWindow(title: type.rawValue.capitalized)
        let oauthController = window.oauthController
        authClient.authorizeURLHandler = oauthController

        // OAuthSwift.setLogLevel(.warn)
        let state = generateState(withLength: 20)

        authClient.authorize(
            withCallbackURL: callbackURL,
            scope: scope,
            state: state) { result in
            switch result {
            case .success(let (credential, _, _)):
                Logger.shared.logDebug("\(type.rawValue) Token: \(credential.oauthToken)", category: .network)

                if type.rawValue == IdentityRequest.Provider.google.rawValue {
                    Persistence.Authentication.googleAccessToken = credential.oauthToken
                    Persistence.Authentication.googleRefreshToken = credential.oauthRefreshToken
                }

                switch buttonType {
                case .connect:
                    IdentityRequest().create(credential.oauthToken, type).then { _ in
                        onConnect?()
                    }
                case .signin:
                    AccountManager().signInWithProvider(type, credential.oauthToken).then { _ in
                        onConnect?()
                    }
                }
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .network)
                onFailure?()
            }
        }
    }
}
