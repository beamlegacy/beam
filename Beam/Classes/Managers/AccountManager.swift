import Foundation
import PromiseKit
import Promises

class AccountManager {
    var loggedIn: Bool {
        Persistence.Authentication.accessToken != nil
    }

    let userSessionRequest = UserSessionRequest()
}

// Foundation
extension AccountManager {
    @discardableResult
    func signIn(_ email: String,
                _ password: String,
                _ completionHandler: ((Swift.Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userSessionRequest.signIn(email: email, password: password) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not signin: \(error.localizedDescription)", category: .network)
                    completionHandler?(.failure(error))
                case .success(let signIn):
                    Persistence.Authentication.accessToken = signIn.accessToken
                    Persistence.Authentication.email = email
                    Persistence.Authentication.password = password
                    LibrariesManager.shared.setSentryUser()

                    Logger.shared.logInfo("signIn succeeded: \(signIn.accessToken ?? "-")", category: .network)
                    completionHandler?(.success(true))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not signin: \(error.localizedDescription)", category: .network)
            completionHandler?(.failure(error))
        }
        return nil
    }

    @discardableResult
    func signUp(_ email: String,
                _ password: String,
                _ completionHandler: ((Swift.Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userSessionRequest.signUp(email, password) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not sign up: \(error.localizedDescription)", category: .network)
                    completionHandler?(.failure(error))
                case .success(let signUp):
                    Logger.shared.logInfo("signUp succeeded: \(signUp.user?.email ?? "-")", category: .network)
                    completionHandler?(.success(true))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not sign up: \(error.localizedDescription)", category: .network)
            completionHandler?(.failure(error))
        }
        return nil
    }

    @discardableResult
    func forgotPassword(email: String,
                        _ completionHandler: ((Swift.Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userSessionRequest.forgotPassword(email: email) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not forgot password: \(error.localizedDescription)", category: .network)
                    completionHandler?(.failure(error))
                case .success:
                    Logger.shared.logInfo("forgot Password succeeded", category: .network)
                    completionHandler?(.success(true))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not forgot password: \(error.localizedDescription)", category: .network)
            completionHandler?(.failure(error))
        }
        return nil
    }

    static func logout() {
        Persistence.cleanUp()
        Logger.shared.logDebug("Logged out", category: .general)
    }
}

// PromiseKit
extension AccountManager {
    func signIn(_ email: String, _ password: String) -> PromiseKit.Promise<Bool> {
        let promise: PromiseKit.Promise<UserSessionRequest.SignIn> = userSessionRequest.signIn(email: email, password: password)

        return promise.then { signIn -> PromiseKit.Promise<Bool> in
            Persistence.Authentication.accessToken = signIn.accessToken
            Persistence.Authentication.email = email
            Persistence.Authentication.password = password
            LibrariesManager.shared.setSentryUser()
            Logger.shared.logInfo("signIn succeeded: \(signIn.accessToken ?? "-")", category: .network)
            return .value(true)
        }
    }

    func signUp(_ email: String, _ password: String) -> PromiseKit.Promise<Bool> {
        let promise: PromiseKit.Promise<UserSessionRequest.SignUp> = userSessionRequest.signUp(email, password)

        return promise.map { _ in true }
    }

    func forgotPassword(email: String) -> PromiseKit.Promise<Bool> {
        let promise: PromiseKit.Promise<UserSessionRequest.ForgotPassword> = userSessionRequest.forgotPassword(email: email)

        return promise.map { _ in true }
    }
}

// Promises
extension AccountManager {
    func signIn(_ email: String, _ password: String) -> Promises.Promise<Bool> {
        let promise: Promises.Promise<UserSessionRequest.SignIn> = userSessionRequest.signIn(email: email, password: password)

        return promise.then { signIn in
            Persistence.Authentication.accessToken = signIn.accessToken
            Persistence.Authentication.email = email
            Persistence.Authentication.password = password
            LibrariesManager.shared.setSentryUser()
            Logger.shared.logInfo("signIn succeeded: \(signIn.accessToken ?? "-")", category: .network)
            return Promise(true)
        }
    }

    func signUp(_ email: String, _ password: String) -> Promises.Promise<Bool> {
        let promise: Promises.Promise<UserSessionRequest.SignUp> = userSessionRequest.signUp(email, password)

        return promise.then { _ in true }
    }

    func forgotPassword(email: String) -> Promises.Promise<Bool> {
        let promise: Promises.Promise<UserSessionRequest.ForgotPassword> = userSessionRequest.forgotPassword(email: email)

        return promise.then { _ in true }
    }
}
