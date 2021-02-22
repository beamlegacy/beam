import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
class PersistenceTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        let email = "foobar"
        it("saves email") {
            Persistence.Authentication.email = email
            expect(Persistence.Authentication.email).to(equal(email))
        }
    }
}
