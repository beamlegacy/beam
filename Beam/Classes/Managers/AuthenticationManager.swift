import Foundation
import JWTDecode
import BeamCore
import Combine

class AuthenticationManager {
    static var shared = AuthenticationManager()
    weak var account: BeamAccount?

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
        Logger.shared.logInfo("Deallocating \(type(of: self))", category: .memory)
        semaphore.signal()
    }
    var accessToken: String? {
        get { Persistence.Authentication.accessToken }
        set { }
    }
    var refreshToken: String? {
        get { Persistence.Authentication.refreshToken }
        set {
            Persistence.Authentication.refreshToken = newValue
            persistenceDidUpdate()
        }
    }
    var username: String? {
        get { Persistence.Authentication.username }
        set {
            Persistence.Authentication.username = newValue
            persistenceDidUpdate()
        }
    }
    var isAuthenticated: Bool {
        let now = BeamDate.now
        guard let accessToken = accessToken, let refreshToken = refreshToken,
              let accessTokenExpirationDate = Self.expirationDate(accessToken),
              let refreshTokenExpirationDate = Self.expirationDate(refreshToken),
            (accessTokenExpirationDate > now || refreshTokenExpirationDate > now) else {
            return false
        }

        return true
    }

    var isLoggedIn: Bool {
        if let account = account {
            return account.signedIn && AuthenticationManager.shared.isAuthenticated
        }
        return false
    }

    private var authenticationSubject = PassthroughSubject<Bool, Never>()

    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> {
        authenticationSubject.eraseToAnyPublisher()
    }

    func persistenceDidUpdate() {
        authenticationSubject.send(isAuthenticated)
    }

    func updateAccessTokenIfNeeded() {
        // Refresh the token in a sync matter
        if !accessTokenIsValid(), refreshTokenIsValid() {
            Logger.shared.logDebug("AccessToken is invalid, refresh token is valid", category: .appLifeCycle)
            updateAccessToken()
        }
    }

    private func log(message: String) {
        Logger.shared.logDebug(message, category: .network)
    }

    // We want to make sure only one call to refresh token is done at a time, as we have many parallels
    // network API calls and we don't want to have multiple refresh calls when a token suddenly expires
    private func updateAccessToken() {
        Logger.shared.logDebug("AuthenticationManager.refreshToken", category: .network)

        group.enter()
        queue.addOperation {
            // Token might have been updated by another API call by then, we should test it again
            guard self.account != nil else {
                self.log(message: "missing BeamAccount")
                self.group.leave()
                return
            }

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

            Logger.shared.logInfo("accessToken has expired, updating it", category: .network)
        }

        group.wait()
    }

    private func handleUpdateAccessTokenFailure(_ error: Error) {
        Logger.shared.logDebug("Can't refresh token, removing existing tokens", category: .appLifeCycle)
        self.accessToken = nil
        self.refreshToken = nil
    }

    private func handleUpdateAccessTokenSuccess(_ refresh: UserSessionRequest.RenewCredentials, accessToken: String) {
        guard let newAccessToken = refresh.accessToken,
              let newRefreshToken = refresh.refreshToken else {
            Logger.shared.logDebug("Can't refresh token, returned success, no error and no token. Removing existing tokens", category: .appLifeCycle)
            self.accessToken = nil
            self.refreshToken = nil
            return
        }

        Logger.shared.logInfo("Expiration \(String(describing: Self.expirationDate(accessToken))) -> \(String(describing: Self.expirationDate(newAccessToken)))", category: .network)

        self.accessToken = newAccessToken
        self.refreshToken = newRefreshToken
    }

    private func accessTokenIsValid() -> Bool {
        guard let accessToken = accessToken, let expirationDate = Self.expirationDate(accessToken) else {
            return false
        }

        // Adding 1 minute to be safe, token can be non-expired now but
        // will be within seconds
        let result = expirationDate > BeamDate.now.addingTimeInterval(60)
        if !result {
            Logger.shared.logDebug("Access token is invalid: \(expirationDate)", category: .network)
        }

        return result
    }

    private func refreshTokenIsValid() -> Bool {
        guard let refreshToken = refreshToken, let expirationDate = Self.expirationDate(refreshToken) else {
            return false
        }

        // add 1 hour just in case
        let result = expirationDate > BeamDate.now.addingTimeInterval(60 * 60)
        if result {
            Logger.shared.logInfo("Refresh token is valid: \(expirationDate)", category: .network)
        }

        return result
    }

    static func expirationDate(_ accessToken: String) -> Date? {
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
            result["AccessTokenExpirationDate"] = Self.expirationDate(accessToken)
        }

        if let refreshToken = refreshToken {
            result["RefreshTokenExpirationDate"] = Self.expirationDate(refreshToken)
        }

        return result
    }
}
