import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import PromiseKit
import Promises

@testable import Beam
@testable import BeamCore

class AccountManagerTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        let sut = AccountManager()
        let existingAccountEmail = Configuration.testAccountEmail
        let nonExistingAccountEmail = "fabien+test-\(UUID())@beamapp.co"
        let beamHelper = BeamTestsHelper()
        let fixedDate = "2021-03-19T12:21:03Z"

        beforeEach {
            BeamDate.freeze(fixedDate)
            AccountManager.logout()

            beamHelper.beginNetworkRecording()
        }

        afterEach {
            beamHelper.endNetworkRecording()
            BeamDate.reset()
        }

        func isLoggedIn() -> Bool {
            AuthenticationManager.shared.isAuthenticated
        }

        // MARK: forgotPassword
        describe(".forgotPassword") {
            context("with Foundation") {
                context("with existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.forgotPassword(email: existingAccountEmail) { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }
                    }
                }

                context("with non-existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.forgotPassword(email: nonExistingAccountEmail) { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }
                    }
                }
            }
        }

        // MARK: resendVerificationEmail
        describe(".resendVerificationEmail") {
            context("with Foundation") {
                context("with existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.resendVerificationEmail(email: existingAccountEmail) { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }
                    }
                }

                context("with non-existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.resendVerificationEmail(email: nonExistingAccountEmail) { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }
                    }
                }
            }
        }

        // MARK: signUp
        describe(".signUp()") {
            let password = String.random(length: 12)

            context("with Foundation") {
                let nonExistingAccountEmail = "fabien+test-\(UUID())@beamapp.co"

                context("with existing account") {
                    it("returns an error") {
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.signUp(existingAccountEmail, password) { result in
                                expect { try result.get() }.to(throwError { (error: APIRequestError) in
                                    let errorable = UserSessionRequest.SignUp(
                                        user: nil,
                                        errors: [UserErrorData(message: "A user already exists with this email",
                                                               path: ["arguments", "email"])]
                                    )

                                    expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                                })
                                done()
                            }
                        }
                    }
                }

                context("with non-existing account") {
                    it("doesn't return an error") {
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.signUp(nonExistingAccountEmail, password) { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }
                    }
                }
            }
        }

        // MARK: signIn
        describe(".signIn()") {
            context("with Foundation") {
                context("with good password") {
                    let password = Configuration.testAccountPassword

                    it("authenticates") {
                        expect(isLoggedIn()).to(beFalse())

                        waitUntil(timeout: .seconds(10)) { done in
                            sut.signIn(email: existingAccountEmail, password: password, runFirstSync: true, completionHandler: { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            })
                        }

                        expect(isLoggedIn()).to(beTrue())
                    }
                }

                context("with wrong password") {
                    let password = "wrong password"

                    it("doesn't authenticate") {
                        expect(isLoggedIn()).to(beFalse())
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.signIn(email: existingAccountEmail, password: password, runFirstSync: true, completionHandler: { result in
                                expect { try result.get() }.to(throwError { (error: APIRequestError) in
                                    let errorable = UserSessionRequest.SignIn(
                                        accessToken: nil,
                                        refreshToken: nil,
                                        errors: [UserErrorData(message: "Invalid password", path: ["arguments", "password"])]
                                    )

                                    expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                                })
                                done()
                            })
                        }
                        expect(isLoggedIn()).to(beFalse())
                    }
                }
            }
        }
    }
}
