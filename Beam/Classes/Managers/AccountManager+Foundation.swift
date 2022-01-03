import Foundation
import BeamCore

extension AccountManager {
    @discardableResult
    func refreshToken(_ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        guard let accessToken = Persistence.Authentication.accessToken,
              let refreshToken = Persistence.Authentication.refreshToken else {
            completionHandler?(.success(false))
            return nil
        }

        do {
            return try self.userSessionRequest.refreshToken(accessToken: accessToken, refreshToken: refreshToken) { result in
                switch result {
                case .failure(let error):
                    completionHandler?(.failure(error))
                case .success(let refresh):
                    guard let newAccessToken = refresh.accessToken, refresh.refreshToken != nil else {
                        completionHandler?(.failure(APIRequestError.parserError))
                        return
                    }

                    Logger.shared.logInfo("Expiration \(String(describing: AuthenticationManager.expirationDate(accessToken))) -> \(String(describing: AuthenticationManager.expirationDate(newAccessToken)))", category: .network)
                    EventsTracker.logBreadcrumb(message: "Refreshed access token and refresh token",
                                                       category: "app.lifecycle",
                                                       type: "system")

                    Persistence.Authentication.accessToken = refresh.accessToken
                    Persistence.Authentication.refreshToken = refresh.refreshToken
                    AuthenticationManager.shared.persistenceDidUpdate()
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
    func signIn(email: String,
                password: String,
                completionHandler: ((Result<Bool, Error>) -> Void)? = nil,
                syncCompletion: ((Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userSessionRequest.signIn(email: email, password: password) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not signin: \(error.localizedDescription)", category: .network)
                    completionHandler?(.failure(error))
                case .success(let signIn):
                    Persistence.Authentication.accessToken = signIn.accessToken
                    Persistence.Authentication.refreshToken = signIn.refreshToken
                    Persistence.Authentication.email = email
                    Persistence.Authentication.password = password
                    AuthenticationManager.shared.persistenceDidUpdate()
                    LibrariesManager.shared.setSentryUser()

                    // Syncing with remote API, AppDelegate needs to be called in mainthread
                    // TODO: move this syncData to a manager instead.
                    DispatchQueue.main.async {
                        // We sync data *after* we potentially connected to websocket, to make sure we don't miss any data
                        AppDelegate.main.beamObjectManager.liveSync { _ in
                            var callsToWait = 2
                            let callNetworkCompletionIfNeeded: () -> Void = {
                                callsToWait -= 1
                                if callsToWait == 0 {
                                    syncCompletion?(.success(true))
                                }
                            }
                            AppDelegate.main.syncDataWithBeamObject { _ in
                                callNetworkCompletionIfNeeded()
                            }
                            AppDelegate.main.getUserInfos { _ in
                                callNetworkCompletionIfNeeded()
                            }
                        }
                    }

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
    func signInWithProvider(provider: IdentityRequest.Provider,
                            accessToken: String,
                            completionHandler: ((Result<Bool, Error>) -> Void)? = nil,
                            syncCompletion: ((Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userSessionRequest.signInWithProvider(provider: provider, accessToken: accessToken) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not signin: \(error.localizedDescription)", category: .network)
                    completionHandler?(.failure(error))
                case .success(let signIn):
                    Persistence.Authentication.accessToken = signIn.accessToken
                    Persistence.Authentication.refreshToken = signIn.refreshToken
                    if Persistence.Authentication.email != signIn.me?.email {
                        Persistence.Authentication.email = signIn.me?.email
                        Persistence.Authentication.password = nil
                    }
                    AuthenticationManager.shared.persistenceDidUpdate()
                    LibrariesManager.shared.setSentryUser()

                    // Syncing with remote API, AppDelegate needs to be called in mainthread
                    // TODO: move this syncData to a manager instead.
                    DispatchQueue.main.async {
                        // We sync data *after* we potentially connected to websocket, to make sure we don't miss any data
                        var callsToWait = 2
                        let callNetworkCompletionIfNeeded: () -> Void = {
                            callsToWait -= 1
                            if callsToWait == 0 {
                                syncCompletion?(.success(true))
                            }
                        }
                        AppDelegate.main.syncDataWithBeamObject { _ in
                            callNetworkCompletionIfNeeded()
                        }
                        AppDelegate.main.getUserInfos { _ in
                            callNetworkCompletionIfNeeded()
                        }
                    }

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
                _ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
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
                        _ completionHandler: ((Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
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

    @discardableResult
    func getUserInfos(_ completionHandler: ((Result<UserInfoRequest.UserInfos, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userInfoRequest.getUserInfos { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not get user infos: \(error.localizedDescription)", category: .network)
                    completionHandler?(.failure(error))
                case .success(let infos):
                    Logger.shared.logInfo("Get user infos succeeded", category: .network)
                    AuthenticationManager.shared.username = infos.username
                    completionHandler?(.success(infos))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not get user infos: \(error.localizedDescription)", category: .network)
            completionHandler?(.failure(error))
        }
        return nil
    }

    @discardableResult
    func setUsername(username: String, _ completionHandler: ((Result<String, Error>) -> Void)? = nil) -> URLSessionTask? {
        do {
            return try userInfoRequest.setUsername(username: username) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logInfo("Could not set username: \(error.localizedDescription)", category: .network)
                    completionHandler?(.failure(error))
                case .success(let infos):
                    guard let username = infos.me?.username else {
                        completionHandler?(.failure(APIRequestError.parserError))
                        return
                    }
                    Logger.shared.logInfo("Set username succeeded", category: .network)
                    AuthenticationManager.shared.username = username
                    completionHandler?(.success(username))
                }
            }
        } catch {
            Logger.shared.logInfo("Could not set username: \(error.localizedDescription)", category: .network)
            completionHandler?(.failure(error))
        }
        return nil
    }

    static func logout() {
        Persistence.cleanUp()
        AppDelegate.main.disconnectWebSockets()
        AuthenticationManager.shared.persistenceDidUpdate()
        Logger.shared.logDebug("Logged out", category: .general)
    }
}
