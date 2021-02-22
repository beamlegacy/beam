import Foundation
import XCTest
import Quick
import Nimble
import Promises
import PromiseKit

@testable import Beam
class APIRequestTests: QuickSpec {
    var sut: APIRequest!

    struct ForgotPasswordParameters: Encodable {
        let email: String
    }

    class ForgotPassword: Decodable, Errorable {
        let success: Bool
        let errors: [UserErrorData]?
    }

    // swiftlint:disable:next function_body_length
    override func spec() {
        let email = Configuration.testAccountEmail
        let variables = ForgotPasswordParameters(email: email)
        let bodyParamsRequest = GraphqlParameters(fileName: "forgot_password", variables: variables)
        let backgroundQueue = DispatchQueue.global(qos: .background)
        beforeEach {
            self.sut = APIRequest()
            Configuration.reset()
        }

        afterEach {
            Configuration.reset()
        }

        context("with Foundation") {
            it("sends a request") {
                waitUntil(timeout: .seconds(10)) { done in
                    _ = try? self.sut.performRequest(bodyParamsRequest: bodyParamsRequest,
                                                          authenticatedCall: false) { (result: Swift.Result<ForgotPassword, Error>) in
                        let forgotPassword: ForgotPassword? = try? result.get()

                        // Result should not generate error, and be true since this email exists
                        expect { try result.get() }.toNot(throwError())
                        expect(forgotPassword?.success).to(beTrue())
                        done()
                    }
                }
            }

            context("with wrong api hostname") {
                beforeEach {
                    Configuration.apiHostname = "localhost"
                }

                it("manages errors") {
                    waitUntil(timeout: .seconds(1)) { done in
                        _ = try? self.sut.performRequest(bodyParamsRequest: bodyParamsRequest,
                                                              authenticatedCall: false) { (result: Swift.Result<ForgotPassword, Error>) in
                            expect { try result.get() }.to(throwError { (error: NSError) in
                                expect(error.code).to(equal(-1004))
                            })
                            done()
                        }
                    }
                }
            }
        }

        context("with PromiseKit") {
            it("sends a request") {
                waitUntil(timeout: .seconds(10)) { [unowned self] done in
                    let promise: PromiseKit.Promise<ForgotPassword> = self.sut
                        .performRequest(bodyParamsRequest: bodyParamsRequest,
                                        authenticatedCall: false)
                    promise.done(on: backgroundQueue) { (forgotPassword: ForgotPassword) in
                        expect(forgotPassword.success).to(beTrue())
                        done()
                    }
                    .catch { _ in }
                }
            }

            context("with wrong api hostname") {
                beforeEach {
                    Configuration.apiHostname = "localhost"
                }

                it("manages errors") {
                    waitUntil(timeout: .seconds(1)) { done in
                        let promise: PromiseKit.Promise<ForgotPassword> = self.sut
                            .performRequest(bodyParamsRequest: bodyParamsRequest,
                                            authenticatedCall: false)
                        promise.done(on: backgroundQueue) { _ in

                        }
                        .catch(on: backgroundQueue) { error in
                            expect((error as NSError).code).to(equal(-1004))
                            done()
                        }
                    }
                }
            }
        }

        context("with Promises") {
            it("sends a request") {
                waitUntil(timeout: .seconds(10)) { [unowned self] done in
                    let promise: Promises.Promise<ForgotPassword> = self.sut
                        .performRequest(bodyParamsRequest: bodyParamsRequest,
                                        authenticatedCall: false)
                    promise.then(on: backgroundQueue) { (forgotPassword: ForgotPassword) in
                        expect(forgotPassword.success).to(beTrue())
                        done()
                    }
                    .catch { _ in }
                }
            }

            context("with wrong api hostname") {
                beforeEach {
                    Configuration.apiHostname = "localhost"
                }

                it("manages errors") {
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: Promises.Promise<ForgotPassword> = self.sut
                            .performRequest(bodyParamsRequest: bodyParamsRequest,
                                            authenticatedCall: false)
                        promise.then(on: backgroundQueue) { (forgotPassword: ForgotPassword) in
                            expect(forgotPassword.success).to(beTrue())
                            done()
                        }
                        .catch(on: backgroundQueue) { error in
                            expect((error as NSError).code).to(equal(-1004))
                            done()
                        }
                    }
                }
            }
        }
    }
}
