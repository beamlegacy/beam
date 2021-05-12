import SwiftUI
import BeamCore
import OAuthSwift

struct GoogleButton: View {
    var buttonType: OauthButton.ButtonType = .connect
    var onClick: (() -> Void)?
    var onConnect: (() -> Void)?
    var onFailure: (() -> Void)?

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
                    onFailure: onFailure)
    }
}

struct GoogleButton_Previews: PreviewProvider {
    static var previews: some View {
        GoogleButton()
    }
}
