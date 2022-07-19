import Foundation
import XCTest
import Quick
import Nimble

@testable import Beam
@testable import BeamCore

class APIRequestTests: QuickSpec {
    var sut: APIRequest!

    // swiftlint:disable:next function_body_length
    override func spec() {
        let beamHelper = BeamTestsHelper()

        beforeEach {
            self.sut = APIRequest()
            BeamDate.freeze("2022-04-18T06:00:03Z")
            Configuration.reset()
        }

        afterEach {
            Configuration.reset()
            beamHelper.endNetworkRecording()
            BeamDate.reset()
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

                    context("with FeatureFlags.values.syncEnabled=false") {
                        var oldSyncEnabled:Bool = false

                        beforeEach {
                            oldSyncEnabled = FeatureFlags.current.syncEnabled
                            FeatureFlags.testSetSyncEnabled(false)
                        }

                        afterEach {
                            FeatureFlags.testSetSyncEnabled(oldSyncEnabled)

                        }

                        it("fails fast") {
                            waitUntil(timeout: .seconds(1)) { done in
                                expect {
                                    _ = try self.sut.performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<UserMe, Error>) in
                                        fail("Should not actually send a response")
                                        done()
                                    }
                                }.to(throwError {(error: APIRequestError) in
                                    expect(error).to(matchError(APIRequestError.syncDisabledByFeatureFlag))
                                })
                                done()
                            }
                        }
                    }
                }

                context("with wrong api hostname") {
                    let originalApiHostname = Configuration.apiHostname
                    beforeEach {
                        Configuration.apiHostname = "http://localhost2"
                        beamHelper.disableNetworkRecording()
                        BeamURLSession.shouldNotBeVinyled = true
                    }
                    afterEach {
                        Configuration.apiHostname = originalApiHostname
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

            context("with async") {
                context("with good api hostname") {
                    beforeEach {
                        beamHelper.beginNetworkRecording()
                    }
                    asyncIt("sends a request") {
                        let forgotPassword: ForgotPassword = try await self.sut.performRequest(bodyParamsRequest: bodyParamsRequest,authenticatedCall: false)
                        expect(forgotPassword.success).to(beTrue())
                    }
                    context("with FeatureFlags.values.syncEnabled=false") {
                        var oldSyncEnabled:Bool = false

                        beforeEach {
                            oldSyncEnabled = FeatureFlags.current.syncEnabled
                            FeatureFlags.testSetSyncEnabled(false)
                        }

                        afterEach {
                            FeatureFlags.testSetSyncEnabled(oldSyncEnabled)

                        }
                        asyncIt("fails fast") {
                            do {
                                let _: ForgotPassword = try await self.sut.performRequest(bodyParamsRequest: bodyParamsRequest,authenticatedCall: false)
                            } catch {
                                switch error as! APIRequestError {
                                case .syncDisabledByFeatureFlag:
                                    return;
                                default:
                                    fail("Wrong error: \(error)")
                                }
                            }
                            fail("Failed to throw error")
                        }
                    }
                }

                context("with wrong api hostname") {
                    let originalApiHostname = Configuration.apiHostname
                    beforeEach {
                        Configuration.apiHostname = "http://localhost2"
                        beamHelper.disableNetworkRecording()
                        BeamURLSession.shouldNotBeVinyled = true
                    }
                    afterEach {
                        BeamURLSession.shouldNotBeVinyled = false
                        Configuration.apiHostname = originalApiHostname
                    }

                   asyncIt("manages errors") {
                        do {
                            let _: ForgotPassword = try await self.sut.performRequest(bodyParamsRequest: bodyParamsRequest,authenticatedCall: false)
                        } catch {
                            expect( (error as NSError).code) == NSURLErrorCannotFindHost
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

            context("with async") {
                context("with good api hostname") {
                    asyncIt("sends a request") {
                        let userMe: UserMe = try await self.sut.performRequest(bodyParamsRequest: bodyParamsRequest)
                        expect(userMe).toNot(beNil())
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

                    asyncIt("manages errors") {
                        do {
                            let _: UserMe = try await self.sut.performRequest(bodyParamsRequest: bodyParamsRequest)
                        } catch {
                            switch error as! APIRequestError {
                            case .apiRequestErrors(let errors):
                                expect(errors[0].message).to(equal("Fragment pageInfo was used, but not defined"))
                                break;
                            default:
                                fail("Wrong error: \(error)")
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

                    asyncIt("manages errors") {
                        do {
                            let _: UserMe = try await self.sut.performRequest(bodyParamsRequest: bodyParamsRequest)
                        } catch {
                            expect(error).to(matchError(APIRequestError.parserError))
                        }
                    }
                }
            }
        }

    }
}
