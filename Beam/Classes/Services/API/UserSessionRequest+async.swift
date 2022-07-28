import Foundation

extension UserSessionRequest {
    func signInWithProvider(provider: IdentityRequest.Provider,
                            accessToken: String) async throws -> SignInWithProvider {
        let identity = IdentityType(id: nil, provider: provider.rawValue, accessToken: accessToken)
        let variables = SignInWithProviderParameters(identity: identity)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_in_with_provider", variables: variables)

        let signIn: SignInWithProvider = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        guard signIn.accessToken != nil else {
            throw UserSessionRequestError.signInFailed
        }

        return signIn
    }

    @discardableResult
    func signIn(email: String,
                password: String) async throws -> SignIn {
        let variables = SignInParameters(email: email,
                                         password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_in", variables: variables)

        let signIn: SignIn = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        guard signIn.accessToken != nil else {
            throw UserSessionRequestError.signInFailed
        }

        return signIn
    }

    func signUp(_ email: String,
                _ password: String) async throws -> SignUp {
        let variables = SignUpParameters(email: email, password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_up", variables: variables)

        return try await performRequest(bodyParamsRequest: bodyParamsRequest)
    }

    @discardableResult
    func forgotPassword(email: String) async throws -> ForgotPassword {
        let variables = ForgotPasswordParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "forgot_password", variables: variables)

        let forgotPassword: ForgotPassword = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        guard forgotPassword.success == true else {
            throw UserSessionRequestError.forgotPasswordFailed
        }

        return forgotPassword
    }

    @discardableResult
    func resendVerificationEmail(email: String) async throws -> ResendVerificationEmail {
        let variables = ResendVerificationEmailParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "resend_verification_email", variables: variables)

        let result: ResendVerificationEmail = try await performRequest(bodyParamsRequest: bodyParamsRequest)
        guard result.success == true else {
            throw UserSessionRequestError.resendVerificationEmailFailed
        }

        return result
    }

    func refreshToken(accessToken: String,
                      refreshToken: String) async throws -> RenewCredentials {
        let variables = RefreshTokenParameters(accessToken: accessToken, refreshToken: refreshToken)

        let bodyParamsRequest = GraphqlParameters(fileName: "refresh_token", variables: variables)

        return try await performRequest(bodyParamsRequest: bodyParamsRequest)
    }

    func accountExists(email: String) async throws -> AccountExists {
        let variables = AccountExistsParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "account_exists", variables: variables)

        return try await performRequest(bodyParamsRequest: bodyParamsRequest)
    }

}
