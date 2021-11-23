import SwiftUI
import OAuthSwift
import BeamCore

struct GithubButton: View {
    var buttonType: OAuthButtonType = .connect
    var onClick: (() -> Void)?
    var onConnect: (() -> Void)?
    var onDataSync: (() -> Void)?
    var onFailure: (() -> Void)?

    private let type = IdentityRequest.Provider.github

    private let authClient = OAuth2Swift(
        consumerKey: EnvironmentVariables.Oauth.Github.consumerKey,
        consumerSecret: EnvironmentVariables.Oauth.Github.consumerSecret,
        authorizeUrl: "https://github.com/login/oauth/authorize",
        accessTokenUrl: "https://github.com/login/oauth/access_token",
        responseType: "code"
    )

    // TODO: loc
    var body: some View {
        OauthButton(type: type,
                    authClient: authClient,
                    callbackURL: EnvironmentVariables.Oauth.Github.callbackURL,
                    scope: "user",
                    buttonType: buttonType,
                    onClick: onClick,
                    onConnect: onConnect,
                    onDataSync: onDataSync,
                    onFailure: onFailure) { title in
            Text(title)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .frame(width: buttonType == .connect ? 126 : 145)
        }
    }
}

struct GithubButton_Previews: PreviewProvider {
    static var previews: some View {
        GithubButton()
    }
}
