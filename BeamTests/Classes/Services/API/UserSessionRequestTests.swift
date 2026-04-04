import Foundation
import XCTest
import Quick
import Nimble

@testable import Beam

class UserSessionRequestTests: QuickSpec {
    override func spec() {
        let existingAccountEmail = Configuration.testAccountEmail
        let nonExistingAccountEmail = "fabien+test-\(UUID())@beamapp.co"
        var sut: UserSessionRequest!

        beforeEach {
            sut = UserSessionRequest()
        }

        describe("remote session API disabled") {
            asyncIt("signIn throws networkUnavailable") {
                do {
                    _ = try await sut.signIn(email: existingAccountEmail, password: Configuration.testAccountPassword)
                    fail("expected networkUnavailable")
                } catch {
                    expect(error).to(matchError(APIRequestError.networkUnavailable))
                }
            }

            asyncIt("accountExists returns local stub (false)") {
                let a = try await sut.accountExists(email: existingAccountEmail)
                expect(a.exists).to(beFalse())
                let b = try await sut.accountExists(email: nonExistingAccountEmail)
                expect(b.exists).to(beFalse())
            }
        }
    }
}
