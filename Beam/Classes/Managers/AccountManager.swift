import Foundation
import BeamCore

class AccountManager {
//    let safariDomains: [CFString] = [Configuration.publicHostnameDefault as CFString]

    let userSessionRequest = UserSessionRequest()
    let userInfoRequest = UserInfoRequest()
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
