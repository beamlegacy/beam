import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import Alamofire

@testable import Beam

class BeamTestsHelper {
    static func login() {
        let accountManager = AccountManager()
        let email = Configuration.testAccountEmail
        let password = Configuration.testAccountPassword

        guard !AuthenticationManager.shared.isAuthenticated else { return }

        waitUntil(timeout: .seconds(10)) { done in
            accountManager.signIn(email, password) { _ in
                done()
            }
        }
    }

    static func logout() {
        guard AuthenticationManager.shared.isAuthenticated else { return }
        AccountManager.logout()
    }
}
