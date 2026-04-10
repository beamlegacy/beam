import Foundation
import BeamCore
import Combine

/// Stub — remote auth has been removed. All callers that guard on
/// `isAuthenticated` will now skip network/sync paths.
class AuthenticationManager {
    static var shared = AuthenticationManager()
    weak var account: BeamAccount?

    private init() {}

    var accessToken: String? { nil }
    var refreshToken: String? { nil }

    var username: String? {
        get { Persistence.Authentication.username }
        set { Persistence.Authentication.username = newValue }
    }

    var isAuthenticated: Bool { false }
    var isLoggedIn: Bool { false }

    private var authenticationSubject = PassthroughSubject<Bool, Never>()

    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> {
        authenticationSubject.eraseToAnyPublisher()
    }

    func persistenceDidUpdate() {
        authenticationSubject.send(false)
    }

    func updateAccessTokenIfNeeded() {}

    func hashTokensInfos() -> [String: Any] {
        ["IsAuthenticated": false]
    }
}
