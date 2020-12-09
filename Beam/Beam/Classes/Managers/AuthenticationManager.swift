import Foundation
import JWTDecode
import Alamofire

class AuthenticationManager {
    static var shared = AuthenticationManager()

    // Queue is used to make sure only one refresh at a time is being called on the API
    lazy private var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Authentication queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private let group = DispatchGroup()

    // Semaphore is used because we need to wait in sync while the network call is async in its own
    // thread and we only want to do 1 call at a time
    private let semaphore = DispatchSemaphore(value: 0)
    lazy private var userSessionRequest: UserSessionRequest = {
        return UserSessionRequest()
    }()
    private init() {}
    deinit {
        BMLogger.shared.logInfo("Deallocating \(type(of: self))", category: .memory)
        semaphore.signal()
    }
    var accessToken: String? {
        get { Persistence.Authentication.accessToken }
        set { Persistence.Authentication.accessToken = newValue }
    }
    var refreshToken: String? {
        get { Persistence.Authentication.refreshToken }
        set { Persistence.Authentication.refreshToken = newValue }
    }
    var isAuthenticated: Bool {
        let now = Date()
        guard let accessToken = accessToken,
            let accessTokenExpirationDate = expirationDate(accessToken),
            (accessTokenExpirationDate > now) else {
            return false
        }

        return true
    }

    func updateAccessTokenIfNeeded() {
        // Refresh the token in a sync matter
        if !accessTokenIsValid(), refreshTokenIsValid() {
            BMEventsTracker.shared.logBreadcrumb(message: "AccessToken is invalid, refresh token is valid",
                                               category: "app.lifecycle",
                                               type: "system")
            updateAccessToken()
        }
    }

    private func log(message: String) {
        BMLogger.shared.logDebug(message, category: .network)
        BMEventsTracker.shared.logBreadcrumb(message: message, category: "app.lifecycle", type: "system")
    }

    // We want to make sure only one call to refresh token is done at a time, as we have many parallels
    // network API calls and we don't want to have multiple refresh calls when a token suddenly expires
    private func updateAccessToken() {
        BMLogger.shared.logDebug("AuthenticationManager.refreshToken", category: .network)

        group.enter()
        queue.addOperation {
            // Token might have been updated by another API call by then, we should test it again
            guard !self.accessTokenIsValid() else {
                self.log(message: "accessToken already been refreshed")
                self.group.leave()
                return
            }

            guard self.refreshTokenIsValid() else {
                self.log(message: "refreshToken has become invalid")
                self.group.leave()
                return
            }

            guard let accessToken = self.accessToken, let refreshToken = self.refreshToken else {
                self.log(message: "no accessToken or refreshToken")
                self.group.leave()
                return
            }

            BMLogger.shared.logInfo("accessToken has expired, updating it", category: .network)
            BMEventsTracker.shared.logBreadcrumb(message: "accessToken has expired, updating it",
                                               category: "app.lifecycle",
                                               type: "system")

            self.userSessionRequest.refreshToken(accessToken: accessToken,
                                                 refreshToken: refreshToken) { result in
                                                    switch result {
                                                    case .failure(let error):
                                                        self.handleUpdateAccessTokenFailure(error)
                                                    case .success(let refresh):
                                                        self.handleUpdateAccessTokenSuccess(refresh, accessToken: accessToken)
                                                    }

                                                    self.group.leave()
                                                    self.semaphore.signal()
            }

            self.semaphore.wait()
        }

        group.wait()
    }

    private func handleUpdateAccessTokenFailure(_ error: Error) {
        LibrariesManager.nonFatalError("Can't refresh token, removing existing tokens", error: error)
        BMEventsTracker.shared.logBreadcrumb(message: "Can't refresh token, removing existing tokens",
                                           category: "app.lifecycle",
                                           type: "system")
        self.accessToken = nil
        self.refreshToken = nil
    }

    private func handleUpdateAccessTokenSuccess(_ refresh: UserSessionRequest.RenewCredentials, accessToken: String) {
        if let errors = refresh.errors, !errors.isEmpty {
            LibrariesManager.nonFatalError("Can't refresh token: \(errors.compactMap { $0.message })")
            BMEventsTracker.shared.logBreadcrumb(message: "Can't refresh token, removing existing tokens",
                                               category: "app.lifecycle",
                                               type: "system")
            self.accessToken = nil
            self.refreshToken = nil
        } else if let newAccessToken = refresh.accessToken,
            let newRefreshToken = refresh.refreshToken {
            BMLogger.shared.logInfo("Expiration \(String(describing: self.expirationDate(accessToken))) -> \(String(describing: self.expirationDate(newAccessToken)))", category: .network)
            BMEventsTracker.shared.logBreadcrumb(message: "Refreshed access token and refresh token",
                                               category: "app.lifecycle",
                                               type: "system")

            self.accessToken = newAccessToken
            self.refreshToken = newRefreshToken
        } else {
            LibrariesManager.nonFatalError("Can't refresh token, returned success, no error and no token. Removing existing tokens")
            BMEventsTracker.shared.logBreadcrumb(message: "Can't refresh token, returned success, no error and no token. Removing existing tokens",
                                               category: "app.lifecycle",
                                               type: "system")
            self.accessToken = nil
            self.refreshToken = nil
        }
    }

    private func accessTokenIsValid() -> Bool {
        guard let accessToken = accessToken, let expirationDate = expirationDate(accessToken) else {
            return false
        }

        // add 1 hour just in case
        let result = expirationDate > Date().addingTimeInterval(60 * 60)
        if !result {
            BMLogger.shared.logDebug("Access token is invalid: \(expirationDate)", category: .network)
        }

        return result
    }

    private func refreshTokenIsValid() -> Bool {
        guard let refreshToken = refreshToken, let expirationDate = expirationDate(refreshToken) else {
            return false
        }

        // add 1 hour just in case
        let result = expirationDate > Date().addingTimeInterval(60 * 60)
        if result {
            BMLogger.shared.logInfo("Refresh token is valid: \(expirationDate)", category: .network)
        }

        return result
    }

    private func expirationDate(_ accessToken: String) -> Date? {
        let jwt = try? decode(jwt: accessToken)
        guard let expirationEpoch = jwt?.claim(name: "exp").double else {
            return nil
        }

        return Date(timeIntervalSince1970: expirationEpoch)
    }

    func hashTokensInfos() -> [String: Any] {
        var result: [String: Any] = ["HasAuthorizationToken": accessToken != nil ? true : false,
                                     "IsRefreshTokenValid": refreshTokenIsValid(),
                                     "IsAccessTokenValid": accessTokenIsValid(),
                                     "IsAuthenticated": isAuthenticated]

        if let accessToken = accessToken {
            result["AccessTokenExpirationDate"] = expirationDate(accessToken)
        }

        if let refreshToken = refreshToken {
            result["RefreshTokenExpirationDate"] = expirationDate(refreshToken)
        }

        return result
    }
}
