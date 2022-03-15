import Foundation

enum UserSessionRequestError: Error, Equatable {
    case signInFailed
    case forgotPasswordFailed
    case resendVerificationEmailFailed
    case updatePasswordFailed
}

class UserSessionRequest: APIRequest {
    override init() {
        super.init()
        authenticatedAPICall = false
    }

    struct SignUpParameters: Encodable {
        let email: String
        let password: String
    }

    struct SignUp: Decodable, Errorable {
        let user: UserMe?
        let errors: [UserErrorData]?
    }

    struct SignInParameters: Encodable {
        let email: String
        let password: String
    }

    struct SignInWithProviderParameters: Encodable {
        let identity: IdentityType
    }

    struct SignIn: Decodable, Errorable {
        let accessToken: String?
        let refreshToken: String?
        let errors: [UserErrorData]?
    }

    struct SignInWithProvider: Decodable, Errorable {
        let accessToken: String?
        let refreshToken: String?
        let errors: [UserErrorData]?
        let me: UserMe?
    }

    struct ForgotPasswordParameters: Encodable {
        let email: String
    }

    class ForgotPassword: Decodable, Errorable {
        let success: Bool
        let errors: [UserErrorData]?
    }

    struct ResendVerificationEmailParameters: Encodable {
        let email: String
    }

    class ResendVerificationEmail: Decodable, Errorable {
        let success: Bool
        let errors: [UserErrorData]?
    }

    struct RefreshTokenParameters: Encodable {
        let accessToken: String
        let refreshToken: String
    }

    struct RenewCredentials: Decodable, Errorable {
        let accessToken: String?
        let refreshToken: String?
        let errors: [UserErrorData]?
    }
    
    struct AccountExistsParameters: Encodable {
        let email: String
    }

    struct AccountExists: Decodable, Errorable {
        let exists: Bool
        let errors: [UserErrorData]?
    }
}
