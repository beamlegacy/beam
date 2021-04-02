import Foundation
import PromiseKit
import Promises
import BeamCore

class AccountManager {
//    let safariDomains: [CFString] = [Configuration.publicHostnameDefault as CFString]

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

// Safari Keychain
//extension AccountManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    // Not supported on MacOS
//    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
//        if let e = error as? ASAuthorizationError {
//            switch e.code {
//            case .canceled:
//                Logger.shared.logError("User did cancel authorization.", category: .keychain)
//                return
//            case .failed:
//                Logger.shared.logError("Authorization failed.", category: .keychain)
//            case .invalidResponse:
//                Logger.shared.logError("Authorization returned invalid response.", category: .keychain)
//            case .notHandled:
//                Logger.shared.logError("Authorization not handled.", category: .keychain)
//            case .unknown:
//                if controller.authorizationRequests.contains(where: { $0 is ASAuthorizationPasswordRequest }) {
//                    Logger.shared.logError("Unknown error with password auth", category: .keychain)
//                    return
//                } else {
//                    Logger.shared.logError("Unknown error", category: .keychain)
//                }
//            default:
//                Logger.shared.logError("Unsupported error code.", category: .keychain)
//            }
//        }
//
//        Logger.shared.logError(error.localizedDescription, category: .keychain)
//    }
//
//    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
//        if let passwordCredential = authorization.credential as? ASPasswordCredential {
//            // Sign in using an existing iCloud Keychain credential.
//            let username = passwordCredential.user
//            let password = passwordCredential.password
//            Logger.shared.logDebug(username)
//            Logger.shared.logDebug(password)
//        }
//    }

    // Completion might be called a few times
//    func fetchSafariCredentials(completion: @escaping (String?, String?) -> Void) {
        // `ASAuthorizationPasswordProvider` is not supported on MacOS, leaving if this
        // becomes supported one day

        /*
        let passwordRequest = ASAuthorizationPasswordProvider().createRequest()

//         Sign in with Apple is not supported with Developer ID distribution, you must
//         be on the Appstore to do that
//        let requests = [ASAuthorizationAppleIDProvider().createRequest(),
//                        ASAuthorizationPasswordProvider().createRequest()]
//        let appleIDRequest = ASAuthorizationAppleIDProvider().createRequest()
//        appleIDRequest.requestedScopes = [.email]

        let requests = [passwordRequest]

        let authorizationController = ASAuthorizationController(authorizationRequests: requests)
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
         */
//    }
//
//    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
//        AppDelegate.main.preferencesWindowController.window!
//    }
//
//    func updateSafariCredentials(_ username: String, _ password: String) {
//  This Apple API is not implemented on MacOS
//        if #available(OSX 11.0, *) {
//            for domain in safariDomains {
//                SecAddSharedWebCredential(domain, username as CFString, password as CFString) { error in
//                    if let error = error {
//                        Logger.shared.logError(error.localizedDescription, category: .keychain)
//                    }
//                }
//            }
//        }
//    }

    // https://developer.apple.com/documentation/security/shared_web_credentials/managing_shared_credentials
    // To remove a user’s credentials only when the user deletes her account. Do not use this method when the user simply logs out.
//    func deleteSafariCredentials() {
//  This Apple API is not implemented on MacOS
//        if #available(OSX 11.0, *) {
//            for domain in safariDomains {
//                SecAddSharedWebCredential(domain, "" as CFString, .none) { error in
//                    if let error = error {
//                        Logger.shared.logError(error.localizedDescription, category: .keychain)
//                    }
//                }
//            }
//        }
//    }
//}
