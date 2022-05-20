import Foundation
import XCTest
import Quick
import Nimble
import Promises

@testable import Beam
class UserSessionRequestTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        let existingAccountEmail = Configuration.testAccountEmail
        let password = Configuration.testAccountPassword
        let beamHelper = BeamTestsHelper()
        var sut: UserSessionRequest!

        // I filter those kind of messages in my box to be deleted right away
        let nonExistingAccountEmail = "fabien+test-\(UUID())@beamapp.co"

        beforeEach {
            sut = UserSessionRequest()
            beamHelper.beginNetworkRecording()
        }

        afterEach {
            beamHelper.endNetworkRecording()
        }

        describe(".signIn()") {
            context("with Foundation") {
                context("with good password") {
                    asyncIt("authenticates") {
                        do {
                            let result = try await sut.signIn(email: existingAccountEmail, password: password)
                            expect(result.accessToken).notTo(beNil())
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }

                context("with wrong password") {
                    let password = "wrong password"

                    asyncIt("doesn't authenticate") {
                        do {
                            try await sut.signIn(email: existingAccountEmail, password: password)
                            fail("Should not happen")
                        } catch {
                            let errorable = UserSessionRequest.SignIn(
                                accessToken: nil,
                                refreshToken: nil,
                                errors: [UserErrorData(message: "Invalid password", path: ["arguments", "password"])]
                            )

                            expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                        }
                    }
                }
            }
        }

        describe(".forgotPassword") {
            context("with Foundation") {
                context("with existing account") {
                    asyncIt("returns") {
                        do {
                            let forgotPassword = try await sut.forgotPassword(email: existingAccountEmail)
                            expect(forgotPassword.success).to(beTrue())
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }

                context("with non-existing account") {
                    asyncIt("returns") {
                        do {
                            let forgotPassword = try await sut.forgotPassword(email: nonExistingAccountEmail)
                            expect(forgotPassword.success).to(beTrue())
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }
            }
        }
        
        describe(".accountExists()") {
            context("with Foundation") {
                context("with existing accounts") {
                    asyncIt("returns true") {
                        do {
                            let result = try await sut.accountExists(email: existingAccountEmail)
                            expect(result.exists).to(beTrue())
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }

                context("with unknown account") {
                    asyncIt("returns false") {
                        do {
                            let result = try await sut.accountExists(email: nonExistingAccountEmail)
                            expect(result.exists).to(beFalse())
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
}
