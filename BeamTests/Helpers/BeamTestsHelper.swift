import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam

class BeamTestsHelper {
    static func login() {
        guard !AuthenticationManager.shared.isAuthenticated else { return }

        let accountManager = AccountManager()
        let email = Configuration.testAccountEmail
        let password = Configuration.testAccountPassword

        waitUntil(timeout: .seconds(10)) { done in
            accountManager.signIn(email, password) { result in
                expect { try result.get() } == true
                done()
            }
        }
    }

    static func logout() {
        guard AuthenticationManager.shared.isAuthenticated else { return }
        AccountManager.logout()
    }
}
