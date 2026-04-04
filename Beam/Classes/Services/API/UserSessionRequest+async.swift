import Foundation

extension UserSessionRequest {
    func signInWithProvider(provider: OAuthIdentityProvider,
                            accessToken: String) async throws -> SignInWithProvider {
        throw APIRequestError.networkUnavailable
    }

    @discardableResult
    func signIn(email: String,
                password: String) async throws -> SignIn {
        throw APIRequestError.networkUnavailable
    }

    func signUp(_ email: String,
                _ password: String) async throws -> SignUp {
        throw APIRequestError.networkUnavailable
    }

    @discardableResult
    func forgotPassword(email: String) async throws -> ForgotPassword {
        throw APIRequestError.networkUnavailable
    }

    @discardableResult
    func resendVerificationEmail(email: String) async throws -> ResendVerificationEmail {
        throw APIRequestError.networkUnavailable
    }

    func refreshToken(accessToken: String,
                      refreshToken: String) async throws -> RenewCredentials {
        throw APIRequestError.networkUnavailable
    }

    func accountExists(email: String) async throws -> AccountExists {
        AccountExists(exists: false, errors: nil)
    }
}
