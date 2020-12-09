import Foundation
import Alamofire

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
        let user: Me?
        let errors: [UserErrorData]?
    }

    /// Initiate a user session, potentially with OTP
    /// - Parameter phoneNumber:
    /// - Parameter completionHandler:
    @discardableResult
    func signUp(_ email: String,
                _ password: String,
                _ completionHandler: @escaping (Result<SignUp, Error>) -> Void) -> DataRequest? {
        let variables = SignUpParameters(email: email, password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_up", variables: variables)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<APIResult<SignUp>, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let parserResult):
                if let initSession = parserResult.data?.value, initSession.errors?.isEmpty ?? true {
                    completionHandler(.success(initSession))
                } else {
                    completionHandler(.failure(self.handleError(result: parserResult)))
                }
            }
        }
    }

    struct SignInParameters: Encodable {
        let email: String
        let password: String
    }

    class SignIn: Decodable, Errorable {
        let accessToken: String?
        let refreshToken: String?
        let errors: [UserErrorData]?
    }

    /// SignIn
    /// - Parameter phoneNumber:
    /// - Parameter completionHandler:
    @discardableResult
    func signIn(email: String,
                password: String,
                _ completionHandler: @escaping (Result<SignIn, Error>) -> Void) -> DataRequest? {
        let variables = SignInParameters(email: email,
                                         password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_in", variables: variables)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<APIResult<SignIn>, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let parserResult):
                if let signIn = parserResult.data?.value, signIn.accessToken != nil {
                    completionHandler(.success(signIn))
                } else {
                    completionHandler(.failure(self.handleError(result: parserResult)))
                }
            }
        }
    }

    struct ForgotPasswordParameters: Encodable {
        let email: String
    }

    class ForgotPassword: Decodable, Errorable {
        let success: Bool
        let errors: [UserErrorData]?
    }

    /// ForgotPassword
    /// - Parameter phoneNumber:
    /// - Parameter completionHandler:
    @discardableResult
    func forgotPassword(email: String,
                        _ completionHandler: @escaping (Result<ForgotPassword, Error>) -> Void) -> DataRequest? {
        let variables = ForgotPasswordParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "forgot_password", variables: variables)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<APIResult<ForgotPassword>, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let parserResult):
                if let forgotPassword = parserResult.data?.value, forgotPassword.success == true {
                    completionHandler(.success(forgotPassword))
                } else {
                    completionHandler(.failure(self.handleError(result: parserResult)))
                }
            }
        }
    }

    struct RefreshTokenParameters: Encodable {
        let accessToken: String
        let refreshToken: String
    }

    class RenewCredentials: SignIn {}

    @discardableResult
    func refreshToken(accessToken: String,
                      refreshToken: String,
                      _ completionHandler: @escaping (Result<RenewCredentials, Error>) -> Void) -> DataRequest? {
        let variables = RefreshTokenParameters(accessToken: accessToken,
                                               refreshToken: refreshToken)

        let bodyParamsRequest = GraphqlParameters(fileName: "refresh_token", variables: variables)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<APIResult<RenewCredentials>, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let parserResult):
                if let renewCredendials = parserResult.data?.value,
                    renewCredendials.accessToken != nil,
                    renewCredendials.refreshToken != nil {
                    completionHandler(.success(renewCredendials))
                } else {
                    completionHandler(.failure(self.handleError(result: parserResult)))
                }
            }
        }
    }

    struct SignOut: Decodable, Errorable {
        let signedOut: Bool?
        let errors: [UserErrorData]?
    }

    /// SignOut
    /// - Parameter completionHandler:
    func signOutUser(_ accessToken: String, _ completionHandler: @escaping (Result<SignOut, Error>) -> Void) -> DataRequest? {
        let fileName = "sign_out"
        let bodyParamsRequest = GraphqlParameters(fileName: fileName, variables: EmptyVariable())

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<APIResult<SignOut>, Error>) in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let signOut):
                if let signOut = signOut.data?.value {
                    completionHandler(.success(signOut))
                } else {
                    completionHandler(.failure(self.handleError(result: signOut)))
                }
            }
        }
    }
}
