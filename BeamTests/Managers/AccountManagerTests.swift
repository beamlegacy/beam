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
            context("with PromiseKit") {
                context("with existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.forgotPassword(email: existingAccountEmail)
                            promise.done { success in
                                expect(success) == true
                                done()
                            }.catch { _ in }
                        }
                    }
                }

                context("with non-existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.forgotPassword(email: existingAccountEmail)
                            promise.done { success in
                                expect(success) == true
                                done()
                            }.catch { _ in }
                        }
                    }
                }
            }
            context("with Promises") {
                context("with existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.forgotPassword(email: existingAccountEmail)
                            promise.then { success in
                                expect(success) == true
                                done()
                            }
                        }
                    }
                }

                context("with non-existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.forgotPassword(email: existingAccountEmail)
                            promise.then { success in
                                expect(success) == true
                                done()
                            }
                        }
                    }
                }
            }
        }

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
            context("with PromiseKit") {
                let nonExistingAccountEmail = "fabien+test-\(UUID())@beamapp.co"

                context("with existing account") {
                    it("returns an error") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.signUp(existingAccountEmail, password)
                            promise.catch { error in
                                let errorable = UserSessionRequest.SignUp(
                                    user: nil,
                                    errors: [UserErrorData(message: "A user already exists with this email",
                                                           path: ["arguments", "email"])]
                                )

                                expect(error).to(matchError(APIRequestError.apiErrors(errorable)))

                                done()
                            }
                        }
                    }
                }

                context("with non-existing account") {
                    it("doesn't return an error") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.signUp(nonExistingAccountEmail, password)
                            promise.done { success in
                                expect(success) == true
                                done()
                            }.catch { _ in }
                        }
                    }
                }
            }
            context("with Promises") {
                let nonExistingAccountEmail = "fabien+test-\(UUID())@beamapp.co"

                context("with existing account") {
                    it("returns an error") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.signUp(existingAccountEmail, password)
                            promise.catch { error in
                                let errorable = UserSessionRequest.SignUp(
                                    user: nil,
                                    errors: [UserErrorData(message: "A user already exists with this email",
                                                           path: ["arguments", "email"])]
                                )

                                expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                                done()
                            }
                        }
                    }
                }

                context("with non-existing account") {
                    it("doesn't return an error") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.signUp(nonExistingAccountEmail, password)
                            promise.then { success in
                                expect(success) == true
                                done()
                            }.catch { _ in }
                        }
                    }
                }
            }
        }

        describe(".signIn()") {
            context("with Foundation") {
                context("with good password") {
                    let password = Configuration.testAccountPassword

                    it("authenticates") {
                        expect(sut.loggedIn).to(beFalse())

                        waitUntil(timeout: .seconds(10)) { done in
                            sut.signIn(email: existingAccountEmail, password: password, completionHandler: { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            })
                        }

                        expect(sut.loggedIn).to(beTrue())
                    }
                }

                context("with wrong password") {
                    let password = "wrong password"

                    it("doesn't authenticate") {
                        expect(sut.loggedIn).to(beFalse())
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.signIn(email: existingAccountEmail, password: password, completionHandler: { result in
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
                        expect(sut.loggedIn).to(beFalse())
                    }
                }
            }
            context("with PromiseKit") {
                context("with good password") {
                    let password = Configuration.testAccountPassword

                    it("authenticates") {
                        expect(sut.loggedIn).to(beFalse())
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.signIn(existingAccountEmail, password)
                            promise.done { success in
                                expect(success) == true
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }
                        expect(sut.loggedIn).to(beTrue())
                    }
                }

                context("with wrong password") {
                    let password = "wrong password"

                    it("doesn't authenticate") {
                        expect(sut.loggedIn).to(beFalse())
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.signIn(existingAccountEmail, password)
                            promise.catch { error in
                                let errorable = UserSessionRequest.SignIn(
                                    accessToken: nil,
                                    refreshToken: nil,
                                    errors: [UserErrorData(message: "Invalid password", path: ["arguments", "password"])]
                                )

                                expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                                done()
                            }
                        }
                        expect(sut.loggedIn).to(beFalse())
                    }
                }
            }
            context("with Promises") {
                context("with good password") {
                    let password = Configuration.testAccountPassword

                    it("authenticates") {
                        expect(sut.loggedIn).to(beFalse())
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.signIn(existingAccountEmail, password)
                            promise.then { success in
                                expect(success) == true
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }
                        expect(sut.loggedIn).to(beTrue())
                    }
                }

                context("with wrong password") {
                    let password = "wrong password"

                    it("doesn't authenticate") {
                        expect(sut.loggedIn).to(beFalse())
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.signIn(existingAccountEmail, password)
                            promise.catch { error in
                                let errorable = UserSessionRequest.SignIn(
                                    accessToken: nil,
                                    refreshToken: nil,
                                    errors: [UserErrorData(message: "Invalid password", path: ["arguments", "password"])]
                                )

                                expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                                done()
                            }
                        }
                        expect(sut.loggedIn).to(beFalse())
                    }
                }
            }
        }
    }
}
