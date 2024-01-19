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
        let _ = generateState(withLength: 20)
    }
}
