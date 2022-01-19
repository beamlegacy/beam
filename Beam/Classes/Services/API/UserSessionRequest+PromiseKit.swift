import Foundation
import PromiseKit

extension UserSessionRequest {
    func signInWithProvider(provider: IdentityRequest.Provider, accessToken: String) -> Promise<SignInWithProvider> {
        let identity = IdentityType(id: nil, provider: provider.rawValue, accessToken: accessToken)
        let variables = SignInWithProviderParameters(identity: identity)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_in_with_provider", variables: variables)

        let promise: PromiseKit.Promise<SignInWithProvider> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                             authenticatedCall: false)
        return promise.get { signIn in
            guard signIn.accessToken != nil else {
                throw UserSessionRequestError.signInFailed
            }
        }
    }

    func signIn(email: String, password: String) -> Promise<SignIn> {
        let variables = SignInParameters(email: email,
                                         password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_in", variables: variables)

        let promise: PromiseKit.Promise<SignIn> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                 authenticatedCall: false)

        return promise.get { signIn in
                guard signIn.accessToken != nil else {
                    throw UserSessionRequestError.signInFailed
                }
            }
    }

    func signUp(_ email: String, _ password: String) -> Promise<SignUp> {
        let variables = SignUpParameters(email: email, password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_up", variables: variables)

        return performRequest(bodyParamsRequest: bodyParamsRequest, authenticatedCall: false)
    }

    func forgotPassword(email: String) -> Promise<ForgotPassword> {
        let variables = ForgotPasswordParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "forgot_password", variables: variables)

        let promise: PromiseKit.Promise<ForgotPassword> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                         authenticatedCall: false)
        return promise.get { (forgotPassword: ForgotPassword) in
                guard forgotPassword.success == true else {
                    throw UserSessionRequestError.forgotPasswordFailed
                }
            }
    }

    func resendVerificationEmail(email: String) -> Promise<ResendVerificationEmail> {
        let variables = ResendVerificationEmailParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "resend_verification_email", variables: variables)

        let promise: PromiseKit.Promise<ResendVerificationEmail> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                                  authenticatedCall: false)
        return promise.get { (result: ResendVerificationEmail) in
            guard result.success == true else {
                throw UserSessionRequestError.resendVerificationEmailFailed
            }
        }
    }

    @discardableResult
    func refreshToken(accessToken: String,
                      refreshToken: String) -> Promise<RenewCredentials> {
        let variables = RefreshTokenParameters(accessToken: accessToken, refreshToken: refreshToken)

        let bodyParamsRequest = GraphqlParameters(fileName: "refresh_token", variables: variables)

        return performRequest(bodyParamsRequest: bodyParamsRequest, authenticatedCall: false)
    }
}
