import Foundation
import XCTest
import Quick
import Nimble
import Promises
import PromiseKit

@testable import Beam
@testable import BeamCore

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
        let beamHelper = BeamTestsHelper()

        beforeEach {
            self.sut = APIRequest()
            Configuration.reset()
        }

        afterEach {
            Configuration.reset()
            beamHelper.endNetworkRecording()
        }

        context("with Foundation") {
            context("with good api hostname") {
                beforeEach {
                    beamHelper.beginNetworkRecording()
                }
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
            }

            context("with wrong api hostname") {
                beforeEach {
                    Configuration.apiHostname = "http://localhost2"
                    beamHelper.disableNetworkRecording()
                    BeamURLSession.shouldNotBeVinyled = true
                }
                afterEach {
                    BeamURLSession.shouldNotBeVinyled = false
                }

                it("manages errors") {
                    waitUntil(timeout: .seconds(10)) { done in
                        _ = try? self.sut.performRequest(bodyParamsRequest: bodyParamsRequest,
                                                         authenticatedCall: false) { (result: Swift.Result<ForgotPassword, Error>) in
                            expect { try result.get() }.to(throwError { (error: NSError) in
                                expect(error.code) == NSURLErrorCannotFindHost
                            })
                            done()
                        }
                    }
                }
            }
        }

        context("with PromiseKit") {
            context("with good api hostname") {
                beforeEach {
                    beamHelper.beginNetworkRecording()
                }
                it("sends a request") {
                    waitUntil(timeout: .seconds(10)) { [unowned self] done in
                        let promise: PromiseKit.Promise<ForgotPassword> = self.sut
                            .performRequest(bodyParamsRequest: bodyParamsRequest,
                                            authenticatedCall: false)
                        promise.done { (forgotPassword: ForgotPassword) in
                            expect(forgotPassword.success).to(beTrue())
                            done()
                        }
                        .catch { fail("Should not be called: \($0)"); done() }
                    }
                }
            }

            context("with wrong api hostname") {
                beforeEach {
                    Configuration.apiHostname = "http://localhost2"
                    beamHelper.disableNetworkRecording()
                    BeamURLSession.shouldNotBeVinyled = true
                }
                afterEach {
                    BeamURLSession.shouldNotBeVinyled = false
                }

                it("manages errors") {
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: PromiseKit.Promise<ForgotPassword> = self.sut
                            .performRequest(bodyParamsRequest: bodyParamsRequest,
                                            authenticatedCall: false)
                        promise.done { _ in
                            fail("shouldn't be called")
                        }
                        .catch { error in
                            expect((error as NSError).code) == NSURLErrorCannotFindHost
                            done()
                        }
                    }
                }
            }
        }

        context("with Promises") {
            context("with good api hostname") {
                beforeEach {
                    beamHelper.beginNetworkRecording()
                }

                it("sends a request") {
                    waitUntil(timeout: .seconds(30)) { [unowned self] done in
                        let promise: Promises.Promise<ForgotPassword> = self.sut
                            .performRequest(bodyParamsRequest: bodyParamsRequest,
                                            authenticatedCall: false)
                        promise.then { (forgotPassword: ForgotPassword) in
                            expect(forgotPassword.success).to(beTrue())
                            done()
                        }
                        .catch { _ in }
                    }
                }
            }

            context("with wrong api hostname") {
                beforeEach {
                    Configuration.apiHostname = "http://localhost2"
                    beamHelper.disableNetworkRecording()
                    BeamURLSession.shouldNotBeVinyled = true
                }
                afterEach {
                    BeamURLSession.shouldNotBeVinyled = false
                }

                it("manages errors") {
                    waitUntil(timeout: .seconds(10)) { done in
                        let promise: Promises.Promise<ForgotPassword> = self.sut
                            .performRequest(bodyParamsRequest: bodyParamsRequest,
                                            authenticatedCall: false)
                        promise.then { (forgotPassword: ForgotPassword) in
                            fail("shouldn't be called")
                        }
                        .catch { error in
                            expect((error as NSError).code) == NSURLErrorCannotFindHost
                            done()
                        }
                    }
                }
            }
        }
    }
}
