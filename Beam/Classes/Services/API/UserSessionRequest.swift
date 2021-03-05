import Foundation
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
}

// MARK: PromiseKit
extension UserSessionRequest {
    func signIn(email: String, password: String) -> PromiseKit.Promise<SignIn> {
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
        return promise.get { (forgotPassword: ForgotPassword) in
                guard forgotPassword.success == true else {
                    throw UserSessionRequestError.forgotPasswordFailed
                }
            }
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
        return promise.then { signIn in
            guard signIn.accessToken != nil else {
                throw UserSessionRequestError.signInFailed
            }
        }
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
        return promise.then { forgotPassword in
            guard forgotPassword.success == true else {
                throw UserSessionRequestError.forgotPasswordFailed
            }
        }
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
