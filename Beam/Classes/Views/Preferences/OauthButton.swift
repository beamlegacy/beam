import Foundation
import SwiftUI
import BeamCore
import OAuthSwift

enum OAuthButtonType {
    case connect
    case signin
}

struct OauthButton<Content: View>: View {
    var type: IdentityRequest.Provider
    var authClient: OAuth2Swift
    var callbackURL: String
    var scope: String
    var buttonType: OAuthButtonType = .connect

    var onClick: (() -> Void)?
    var onConnect: (() -> Void)?
    var onDataSync: (() -> Void)?
    var onFailure: (() -> Void)?
    var label: (_ title: String) -> Content

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
            label(buttonText)
        })
    }

    private func connect() {
        let window = AppDelegate.main.openOauthWebViewWindow(title: type.rawValue.capitalized)
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

                switch buttonType {
                case .connect:
                    Task {
                        do {
                            _ = try await IdentityRequest().create(credential.oauthToken, type)
                            onConnect?()
                        } catch {
                            Logger.shared.logError(error.localizedDescription, category: .network)
                            onFailure?()
                        }
                    }
                case .signin:
                    AppData.shared.currentAccount?.signInWithProvider(provider: type, accessToken: credential.oauthToken, runFirstSync: false) { _ in
                        onConnect?()
                    } syncCompletion: { _ in
                        onDataSync?()
                    }
                }
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .network)
                onFailure?()
            }
        }
    }
}
