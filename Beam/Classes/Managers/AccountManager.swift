import Foundation
import Alamofire

class AccountManager {
    var loggedIn: Bool {
        Persistence.Authentication.accessToken != nil
    }
    @discardableResult
    func signIn(email: String,
                password: String,
                _ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) -> DataRequest? {
        UserSessionRequest().signIn(email: email, password: password) { result in
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
    }

    @discardableResult
    func signUp(_ email: String,
                _ password: String,
                _ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) -> DataRequest? {
        UserSessionRequest().signUp(email, password) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logInfo("Could not sign up: \(error.localizedDescription)", category: .network)
                completionHandler?(.failure(error))
            case .success(let signUp):
                Logger.shared.logInfo("signUp succeeded: \(signUp.user?.email ?? "-")", category: .network)
                completionHandler?(.success(true))
            }
        }
    }

    @discardableResult
    func forgotPassword(email: String,
                        _ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) -> DataRequest? {
        UserSessionRequest().forgotPassword(email: email) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logInfo("Could not forgot password: \(error.localizedDescription)", category: .network)
                completionHandler?(.failure(error))
            case .success:
                Logger.shared.logInfo("forgot Password succeeded", category: .network)
                completionHandler?(.success(true))
            }
        }
    }

    static func logout() {
        Persistence.cleanUp()
        Logger.shared.logDebug("Logged out", category: .general)
    }
}
