import Foundation

extension UserSessionRequest {
    func signInWithProvider(provider: IdentityRequest.Provider,
                            accessToken: String,
                            _ completionHandler: @escaping (Result<SignInWithProvider, Error>) -> Void) throws -> URLSessionDataTask? {
        let identity = IdentityType(id: nil, provider: provider.rawValue, accessToken: accessToken)
        let variables = SignInWithProviderParameters(identity: identity)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_in_with_provider", variables: variables)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<SignInWithProvider, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let signIn):
                guard signIn.accessToken != nil else {
                    completionHandler(.failure(UserSessionRequestError.signInFailed))
                    return
                }

                completionHandler(.success(signIn))
            }
        }
    }

    func signIn(email: String,
                password: String,
                _ completionHandler: @escaping (Result<SignIn, Error>) -> Void) throws -> URLSessionDataTask? {
        let variables = SignInParameters(email: email,
                                         password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_in", variables: variables)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<SignIn, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let signIn):
                guard signIn.accessToken != nil else {
                    completionHandler(.failure(UserSessionRequestError.signInFailed))
                    return
                }

                completionHandler(.success(signIn))
            }
        }
    }

    @discardableResult
    func signUp(_ email: String,
                _ password: String,
                _ completionHandler: @escaping (Result<SignUp, Error>) -> Void) throws -> URLSessionDataTask? {
        let variables = SignUpParameters(email: email, password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_up", variables: variables)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

    @discardableResult
    func forgotPassword(email: String,
                        _ completionHandler: @escaping (Result<ForgotPassword, Error>) -> Void) throws -> URLSessionDataTask? {
        let variables = ForgotPasswordParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "forgot_password", variables: variables)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<ForgotPassword, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let forgotPassword):
                guard forgotPassword.success == true else {
                    completionHandler(.failure(UserSessionRequestError.forgotPasswordFailed))
                    return
                }

                completionHandler(.success(forgotPassword))
            }
        }
    }

    @discardableResult
    func resendVerificationEmail(email: String,
                                 _ completionHandler: @escaping (Result<ResendVerificationEmail, Error>) -> Void) throws -> URLSessionDataTask? {
        let variables = ResendVerificationEmailParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "resend_verification_email", variables: variables)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<ResendVerificationEmail, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let result):
                guard result.success == true else {
                    completionHandler(.failure(UserSessionRequestError.resendVerificationEmailFailed))
                    return
                }

                completionHandler(.success(result))
            }
        }
    }

    @discardableResult
    func refreshToken(accessToken: String,
                      refreshToken: String,
                      _ completionHandler: @escaping (Result<RenewCredentials, Error>) -> Void) throws -> URLSessionDataTask? {
        let variables = RefreshTokenParameters(accessToken: accessToken, refreshToken: refreshToken)

        let bodyParamsRequest = GraphqlParameters(fileName: "refresh_token", variables: variables)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

    @discardableResult
    func accountExists(email: String,
                       _ completionHandler: @escaping (Result<AccountExists, Error>) -> Void) throws -> URLSessionDataTask? {
        let variables = AccountExistsParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "account_exists", variables: variables)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

}
