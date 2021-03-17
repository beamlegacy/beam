import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
class PersistenceTests: QuickSpec {
    override func spec() {
        let email = "foobar"
        it("saves email") {
            Persistence.Authentication.email = email
            expect(Persistence.Authentication.email).to(equal(email))
        }

        let text = String.randomTitle()
        it("saves privateKey") {
            Persistence.Encryption.privateKey = text
            expect(Persistence.Encryption.privateKey) == text
        }
    }
}
