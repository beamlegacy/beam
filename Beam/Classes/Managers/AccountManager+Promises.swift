import Foundation
import BeamCore
import Promises

extension AccountManager {
    func signIn(_ email: String, _ password: String) -> Promises.Promise<Bool> {
        let promise: Promises.Promise<UserSessionRequest.SignIn> = userSessionRequest.signIn(email: email, password: password)

        return promise.then { signIn in
            Persistence.Authentication.accessToken = signIn.accessToken
            Persistence.Authentication.refreshToken = signIn.refreshToken
            Persistence.Authentication.email = email
            Persistence.Authentication.password = password
            AuthenticationManager.shared.persistenceDidUpdate()
            ThirdPartyLibrariesManager.shared.updateUser()
            // TODO: move this syncData to a manager instead.
            // We sync data *after* we potentially connected to websocket, to make sure we don't miss any data
            DispatchQueue.main.async {
                AppDelegate.main.beamObjectManager.liveSync { _ in
                    AppDelegate.main.syncDataWithBeamObject()
                }
            }
            Logger.shared.logInfo("signIn succeeded: \(signIn.accessToken ?? "-")", category: .network)
            return Promise(true)
        }
    }

    func signInWithProvider(_ provider: IdentityRequest.Provider, _ accessToken: String) -> Promises.Promise<Bool> {
        let promise: Promises.Promise<UserSessionRequest.SignInWithProvider> = userSessionRequest.signInWithProvider(provider: provider, accessToken: accessToken)

        return promise.then { signIn in
            Persistence.Authentication.accessToken = signIn.accessToken
            Persistence.Authentication.refreshToken = signIn.refreshToken
            if Persistence.Authentication.email != signIn.me?.email {
                Persistence.Authentication.email = signIn.me?.email
                Persistence.Authentication.password = nil
            }
            AuthenticationManager.shared.persistenceDidUpdate()
            ThirdPartyLibrariesManager.shared.updateUser()
            // Syncing with remote API, AppDelegate needs to be called in mainthread
            // TODO: move this syncData to a manager instead.
            // We sync data *after* we potentially connected to websocket, to make sure we don't miss any data
            DispatchQueue.main.async {
                AppDelegate.main.beamObjectManager.liveSync { _ in
                    AppDelegate.main.syncDataWithBeamObject()
                }
            }
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

    func resendVerificationEmail(email: String) -> Promises.Promise<Bool> {
        let promise: Promises.Promise<UserSessionRequest.ResendVerificationEmail> = userSessionRequest.resendVerificationEmail(email: email)

        return promise.then { _ in true }
    }
}
