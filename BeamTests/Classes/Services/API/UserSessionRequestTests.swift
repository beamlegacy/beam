import Foundation
import XCTest
import Quick
import Nimble
import PromiseKit
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
                    it("authenticates") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? sut.signIn(email: existingAccountEmail, password: password) { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }
                    }
                }

                context("with wrong password") {
                    let password = "wrong password"

                    it("doesn't authenticate") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? sut.signIn(email: existingAccountEmail, password: password) { result in
                                expect { try result.get() }.to(throwError { (error: APIRequestError) in
                                    let errorable = UserSessionRequest.SignIn(
                                        accessToken: nil,
                                        refreshToken: nil,
                                        errors: [UserErrorData(message: "Invalid password", path: ["arguments", "password"])]
                                    )

                                    expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                                })
                                done()
                            }
                        }
                    }
                }
            }

            context("with PromiseKit") {
                context("with good password") {
                    it("authenticates") {
                        waitUntil(timeout: .seconds(10)) { done in
                            sut
                                .signIn(email: existingAccountEmail, password: password)
                                .done { signIn in
                                    expect(signIn.accessToken).toNot(beEmpty())
                                    done()
                                }
                                .catch { _ in }
                        }
                    }
                }

                context("with wrong password") {
                    let password = "wrong password"

                    it("doesn't authenticate") {
                        waitUntil(timeout: .seconds(10)) { done in
                            sut
                                .signIn(email: existingAccountEmail, password: password)
                                .done { _ in }
                                .catch { error in
                                    expect(error).to(beAnInstanceOf(APIRequestError.self))

                                    let errorable = UserSessionRequest.SignIn(
                                        accessToken: nil,
                                        refreshToken: nil,
                                        errors: [UserErrorData(message: "Invalid password", path: ["arguments", "password"])]
                                    )

                                    expect(error).to(matchError(APIRequestError.apiErrors(errorable)))

                                    done()
                                }
                        }
                    }
                }
            }

            context("With Promises") {
                context("with good password") {
                    it("authenticates") {
                        waitUntil(timeout: .seconds(10)) { done in
                            sut
                                .signIn(email: existingAccountEmail, password: password)
                                .then { signIn in
                                    expect(signIn.accessToken).toNot(beEmpty())
                                    done()
                                }
                                .catch { _ in }
                        }
                    }
                }

                context("with wrong password") {
                    let password = "wrong password"

                    it("doesn't authenticate") {
                        waitUntil(timeout: .seconds(10)) { done in
                            sut
                                .signIn(email: existingAccountEmail, password: password)
                                .then { _ in }
                                .catch { error in
                                    expect(error).to(beAnInstanceOf(APIRequestError.self))

                                    let errorable = UserSessionRequest.SignIn(
                                        accessToken: nil,
                                        refreshToken: nil,
                                        errors: [UserErrorData(message: "Invalid password", path: ["arguments", "password"])]
                                    )

                                    expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                                    done()
                                }
                        }
                    }
                }
            }
        }

        describe(".forgotPassword") {
            context("with Foundation") {
                context("with existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? sut.forgotPassword(email: existingAccountEmail) { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }
                    }
                }

                context("with non-existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? sut.forgotPassword(email: nonExistingAccountEmail) { result in
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
                            let promise: PromiseKit.Promise<UserSessionRequest.ForgotPassword> = sut
                                .forgotPassword(email: existingAccountEmail)

                            promise.done { forgotPassword in
                                expect(forgotPassword.success).to(beTrue())
                                done()
                            }
                            .catch { _ in }
                        }
                    }
                }

                context("with non-existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<UserSessionRequest.ForgotPassword> = sut
                                .forgotPassword(email: existingAccountEmail)

                            promise.done { forgotPassword in
                                expect(forgotPassword.success).to(beTrue())
                                done()
                            }
                            .catch { _ in }
                        }
                    }
                }
            }

            context("with Promises") {
                context("with existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<UserSessionRequest.ForgotPassword> = sut
                                .forgotPassword(email: existingAccountEmail)

                            promise.then { forgotPassword in
                                expect(forgotPassword.success).to(beTrue())
                                done()
                            }
                            .catch { _ in }
                        }
                    }
                }

                context("with non-existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<UserSessionRequest.ForgotPassword> = sut
                                .forgotPassword(email: existingAccountEmail)

                            promise.then { forgotPassword in
                                expect(forgotPassword.success).to(beTrue())
                                done()
                            }
                            .catch { _ in }
                        }
                    }
                }
            }
        }
        
        describe(".accountExists()") {
            context("with Foundation") {
                context("with existing accounts") {
                    it("returns true") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? sut.accountExists(email: existingAccountEmail) { result in
                                expect { try result.get().exists }.to(beTrue())
                                done()
                            }
                        }
                    }
                }

                context("with unknown account") {
                    it("returns false") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? sut.accountExists(email: nonExistingAccountEmail) { result in
                                expect { try result.get().exists }.to(beFalse())
                                done()
                            }
                        }
                    }
                }
            }
        }
    }
}
