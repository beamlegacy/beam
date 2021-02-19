import Foundation
import Alamofire
import PromiseKit
import Promises

enum UserSessionRequestError: Error, Equatable {
    case signInFailed
    case forgotPasswordFailed
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
        let user: Me?
        let errors: [UserErrorData]?
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

    struct ForgotPasswordParameters: Encodable {
        let email: String
    }

    class ForgotPassword: Decodable, Errorable {
        let success: Bool
        let errors: [UserErrorData]?
    }

    struct RefreshTokenParameters: Encodable {
        let accessToken: String
        let refreshToken: String
    }

    class RenewCredentials: SignIn {}

    @discardableResult
    func refreshToken(accessToken: String,
                      refreshToken: String,
                      _ completionHandler: @escaping (Swift.Result<RenewCredentials, Error>) -> Void) -> DataRequest? {
        let variables = RefreshTokenParameters(accessToken: accessToken,
                                               refreshToken: refreshToken)

        let bodyParamsRequest = GraphqlParameters(fileName: "refresh_token", variables: variables)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<APIResult<RenewCredentials>, Error>) in
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
}

// MARK: Alamofire
extension UserSessionRequest {
    @discardableResult
    func signIn(email: String,
                password: String,
                _ completionHandler: @escaping (Swift.Result<SignIn, Error>) -> Void) -> DataRequest? {
        let variables = SignInParameters(email: email,
                                         password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_in", variables: variables)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<APIResult<SignIn>, Error>) in
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

    @discardableResult
    func signUp(_ email: String,
                _ password: String,
                _ completionHandler: @escaping (Swift.Result<SignUp, Error>) -> Void) -> DataRequest? {
        let variables = SignUpParameters(email: email, password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_up", variables: variables)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<APIResult<SignUp>, Error>) in
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

    @discardableResult
    func forgotPassword(email: String,
                        _ completionHandler: @escaping (Swift.Result<ForgotPassword, Error>) -> Void) -> DataRequest? {
        let variables = ForgotPasswordParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "forgot_password", variables: variables)

        return performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<APIResult<ForgotPassword>, Error>) in
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
}

// MARK: PromiseKit
extension UserSessionRequest {
    func signIn(email: String, password: String) -> PromiseKit.Promise<SignIn> {
        let variables = SignInParameters(email: email,
                                         password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_in", variables: variables)

        let promise: PromiseKit.Promise<SignIn> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                 authenticatedCall: false)
            .get { signIn in
                guard signIn.accessToken != nil else {
                    throw UserSessionRequestError.signInFailed
                }
            }

        return promise
    }

    func signUp(_ email: String,
                _ password: String) -> PromiseKit.Promise<SignUp> {
        let variables = SignUpParameters(email: email, password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_up", variables: variables)

        let promise: PromiseKit.Promise<SignUp> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                 authenticatedCall: false)

        return promise
    }

    func forgotPassword(email: String) -> PromiseKit.Promise<ForgotPassword> {
        let variables = ForgotPasswordParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "forgot_password", variables: variables)

        let promise: PromiseKit.Promise<ForgotPassword> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                         authenticatedCall: false)
            .get { (forgotPassword: ForgotPassword) in
                guard forgotPassword.success == true else {
                    throw UserSessionRequestError.forgotPasswordFailed
                }
            }
        return promise
    }
}

// MARK: Promises
extension UserSessionRequest {
    func signIn(email: String, password: String) -> Promises.Promise<SignIn> {
        let variables = SignInParameters(email: email,
                                         password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_in", variables: variables)

        let promise: Promises.Promise<SignIn> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                               authenticatedCall: false)
            .then { signIn in
                guard signIn.accessToken != nil else {
                    throw UserSessionRequestError.signInFailed
                }
            }

        return promise
    }

    func signUp(_ email: String,
                _ password: String) -> Promises.Promise<SignUp> {
        let variables = SignUpParameters(email: email, password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_up", variables: variables)

        let promise: Promises.Promise<SignUp> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                               authenticatedCall: false)

        return promise
    }

    func forgotPassword(email: String) -> Promises.Promise<ForgotPassword> {
        let variables = ForgotPasswordParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "forgot_password", variables: variables)

        let promise: Promises.Promise<ForgotPassword> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                       authenticatedCall: false)
            .then { forgotPassword in
                guard forgotPassword.success == true else {
                    throw UserSessionRequestError.forgotPasswordFailed
                }
            }
        return promise
    }
}

// MARK: Foundation
extension UserSessionRequest {
    func signIn(email: String,
                password: String,
                _ completionHandler: @escaping (Swift.Result<SignIn, Error>) -> Void) throws -> URLSessionDataTask? {
        let variables = SignInParameters(email: email,
                                         password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_in", variables: variables)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<SignIn, Error>) in
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
                _ completionHandler: @escaping (Swift.Result<SignUp, Error>) -> Void) throws -> URLSessionDataTask? {
        let variables = SignUpParameters(email: email, password: password)

        let bodyParamsRequest = GraphqlParameters(fileName: "sign_up", variables: variables)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completionHandler)
    }

    @discardableResult
    func forgotPassword(email: String,
                        _ completionHandler: @escaping (Swift.Result<ForgotPassword, Error>) -> Void) throws -> URLSessionDataTask? {
        let variables = ForgotPasswordParameters(email: email)

        let bodyParamsRequest = GraphqlParameters(fileName: "forgot_password", variables: variables)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<ForgotPassword, Error>) in
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
}
