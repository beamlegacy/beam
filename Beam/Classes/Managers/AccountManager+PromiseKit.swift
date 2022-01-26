import Foundation
import BeamCore
import PromiseKit

extension AccountManager {
    func signIn(_ email: String, _ password: String) -> Promise<Bool> {
        let promise: Promise<UserSessionRequest.SignIn> = userSessionRequest.signIn(email: email, password: password)

        return promise.then { signIn -> Promise<Bool> in
            Persistence.Authentication.accessToken = signIn.accessToken
            Persistence.Authentication.refreshToken = signIn.refreshToken
            Persistence.Authentication.email = email
            Persistence.Authentication.password = password
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

            return .value(true)
        }
    }

    func signInWithProvider(_ provider: IdentityRequest.Provider, _ accessToken: String) -> Promise<Bool> {
        let promise: Promise<UserSessionRequest.SignInWithProvider> = userSessionRequest.signInWithProvider(provider: provider, accessToken: accessToken)

        return promise.then { signIn -> Promise<Bool> in
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

            return .value(true)
        }
    }

    func signUp(_ email: String, _ password: String) -> Promise<Bool> {
        let promise: Promise<UserSessionRequest.SignUp> = userSessionRequest.signUp(email, password)

        return promise.map { _ in true }
    }

    func forgotPassword(email: String) -> Promise<Bool> {
        let promise: Promise<UserSessionRequest.ForgotPassword> = userSessionRequest.forgotPassword(email: email)

        return promise.map { _ in true }
    }

    func resendVerificationEmail(email: String) -> Promise<Bool> {
        let promise: Promise<UserSessionRequest.ResendVerificationEmail> = userSessionRequest.resendVerificationEmail(email: email)

        return promise.map { _ in true }
    }
}
