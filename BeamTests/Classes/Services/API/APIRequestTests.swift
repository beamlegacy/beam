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

    // swiftlint:disable:next function_body_length
    override func spec() {
        let beamHelper = BeamTestsHelper()

        beforeEach {
            self.sut = APIRequest()
            Configuration.reset()
        }

        afterEach {
            Configuration.reset()
            beamHelper.endNetworkRecording()
        }

        describe("with regular graphql request") {
            struct ForgotPasswordParameters: Encodable {
                let email: String
            }

            class ForgotPassword: Decodable, Errorable {
                let success: Bool
                let errors: [UserErrorData]?
            }
            let email = Configuration.testAccountEmail
            let variables = ForgotPasswordParameters(email: email)
            let bodyParamsRequest = GraphqlParameters(fileName: "forgot_password", variables: variables)

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

        describe("with loaded fragments") {
            struct PaginatedBeamObjectsParameters: Encodable {
                let receivedAtAfter: Date?
                let ids: [UUID]?
                let beamObjectType: String?
                let skipDeleted: Bool?
                let first: Int?
                let after: String?
                let last: Int?
                let before: String?
            }
            class UserMe: Decodable, Errorable, APIResponseCodingKeyProtocol {
                static let codingKey = "me"
                var id: String?
                var username: String?
                var email: String?
                var unconfirmedEmail: String?
                var beamObjects: [BeamObject]?
                var paginatedBeamObjects: PaginatedBeamObjects?
                var errors: [UserErrorData]?
                var identities: [IdentityType]?
            }

            let variables = PaginatedBeamObjectsParameters(receivedAtAfter: nil,
                                                            ids: [],
                                                            beamObjectType: nil,
                                                            skipDeleted: false,
                                                            first: nil,
                                                            after: nil,
                                                            last: nil,
                                                            before: nil)
            let bodyParamsRequest = GraphqlParameters(fileName: "paginated_beam_objects", variables: variables)

            beforeEach {
                Configuration.reset()
                beamHelper.beginNetworkRecording()
                BeamTestsHelper.login()
            }

            afterEach {
                BeamTestsHelper.logout()
                beamHelper.endNetworkRecording()
                Configuration.reset()
            }
            
            context("with Foundation") {
                context("with good api hostname") {
                    it("sends a request") {
                        waitUntil(timeout: .seconds(10)) { done in
                            _ = try? self.sut.performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<UserMe, Error>) in
                                let _: UserMe? = try? result.get()

                                // Result should not generate error, and be true since this email exists
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }
                    }
                }

                context("with missing fragment import graphql") {
                    let bundle = Bundle(for: type(of: self))
                    guard let filePath = bundle.path(forResource: "paginated_beam_objects_with_import_missing", ofType: "graphql") else {
                        fail("Cannot find path for graphql file")
                        return
                    }
                    let query = try! String(contentsOfFile: filePath)

                    let bodyParamsRequest = GraphqlParameters(query: query, variables: variables)

                    it("manages errors") {
                        waitUntil(timeout: .seconds(10)) { done in
                            _ = try? self.sut.performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<UserMe, Error>) in
                                expect { try result.get() }.to(throwError { (error: APIRequestError) in
                                    switch error {
                                    case .apiRequestErrors(let errors):
                                        expect(errors[0].message).to(equal("Fragment pageInfo was used, but not defined"))
                                        break;
                                    default:
                                        fail("Wrong error: \(error)")
                                    }
                                    
                                })
                                done()
                            }
                        }
                    }
                }
                
                context("with error import graphql") {
                    let bundle = Bundle(for: type(of: self))
                    guard let filePath = bundle.path(forResource: "paginated_beam_objects_with_import_error", ofType: "graphql") else {
                        fail("Cannot find path for graphql file")
                        return
                    }
                    let query = try! String(contentsOfFile: filePath)

                    let bodyParamsRequest = GraphqlParameters(query: query, variables: variables)

                    it("manages errors") {
                        waitUntil(timeout: .seconds(10)) { done in
                            expect { _ = try self.sut.performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<UserMe, Error>) in
                                }                        
                            }.to(throwError { (error: APIRequestError) in
                                expect(error).to(matchError(APIRequestError.parserError))
                            })
                            done()
                        }
                    }
                }
            }
        }

    }
}
