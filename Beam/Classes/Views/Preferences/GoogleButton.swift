import SwiftUI
import BeamCore
import OAuthSwift

struct GoogleButton<Content: View>: View {
    var buttonType: OAuthButtonType = .connect
    var onClick: (() -> Void)?
    var onConnect: (() -> Void)?
    var onDataSync: (() -> Void)?
    var onFailure: (() -> Void)?
    var label: ((_ title: String) -> Content)?

    private let type = IdentityRequest.Provider.google

    private let authClient = OAuth2Swift(
        consumerKey: EnvironmentVariables.Oauth.Google.consumerKey,
        consumerSecret: EnvironmentVariables.Oauth.Google.consumerSecret,
        authorizeUrl: "https://accounts.google.com/o/oauth2/auth",
        accessTokenUrl: "https://accounts.google.com/o/oauth2/token",
        responseType: "code"
    )

    var body: some View {
        OauthButton(type: type,
                    authClient: authClient,
                    callbackURL: EnvironmentVariables.Oauth.Google.callbackURL,
                    scope: "https://www.googleapis.com/auth/userinfo.email",
                    buttonType: buttonType,
                    onClick: onClick,
                    onConnect: onConnect,
                    onDataSync: onDataSync,
                    onFailure: onFailure) { title in
            Group {
                if let label = label {
                    label(title)
                } else {
                    Text(title)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: buttonType == .connect ? 126 : 145)
                }
            }
        }
    }
}

struct GoogleButton_Previews: PreviewProvider {
    static var previews: some View {
        GoogleButton<Text>()
    }
}
