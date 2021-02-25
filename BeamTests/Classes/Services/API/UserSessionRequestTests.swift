import Foundation
import XCTest
import Quick
import Nimble
import PromiseKit
import Promises

@testable import Beam
class UserSessionRequestTests: QuickSpec {
    var sut: UserSessionRequest!

    // swiftlint:disable:next function_body_length
    override func spec() {
        let existingAccountEmail = Configuration.testAccountEmail
        let password = Configuration.testAccountPassword

        // I filter those kind of messages in my box to be deleted right away
        let nonExistingAccountEmail = "fabien+test-\(UUID())@beamapp.co"

        beforeEach {
            self.sut = UserSessionRequest()
        }

        describe(".signIn()") {
            context("with Foundation") {
                context("with good password") {
                    it("authenticates") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? self.sut.signIn(email: existingAccountEmail, password: password) { result in
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
                            let _: URLSessionDataTask? = try? self.sut.signIn(email: existingAccountEmail, password: password) { result in
                                expect { try result.get() }.to(throwError { (error: APIRequestError) in
                                    expect(error.errorDescription).to(equal("Invalid password"))
                                    expect(error).to(matchError(APIRequestError.apiError(["Invalid password"])))
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
                            self.sut
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
                            self.sut
                                .signIn(email: existingAccountEmail, password: password)
                                .done { _ in }
                                .catch { error in
                                    expect(error).to(beAnInstanceOf(APIRequestError.self))
                                    expect(error).to(matchError(APIRequestError.apiError(["Invalid password"])))
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
                            self.sut
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
                            self.sut
                                .signIn(email: existingAccountEmail, password: password)
                                .then { _ in }
                                .catch { error in
                                    expect(error).to(beAnInstanceOf(APIRequestError.self))
                                    expect(error).to(matchError(APIRequestError.apiError(["Invalid password"])))
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
                            let _: URLSessionDataTask? = try? self.sut.forgotPassword(email: existingAccountEmail) { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }
                    }
                }

                context("with non-existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? self.sut.forgotPassword(email: nonExistingAccountEmail) { result in
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
                            let promise: PromiseKit.Promise<UserSessionRequest.ForgotPassword> = self.sut
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
                            let promise: PromiseKit.Promise<UserSessionRequest.ForgotPassword> = self.sut
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
                            let promise: Promises.Promise<UserSessionRequest.ForgotPassword> = self.sut
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
                            let promise: Promises.Promise<UserSessionRequest.ForgotPassword> = self.sut
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
    }
}
