import Foundation
import XCTest
import Quick
import Nimble

@testable import Beam
@testable import BeamCore

class APIRequestTests: QuickSpec {
    var sut: APIRequest!

    override func spec() {
        beforeEach {
            self.sut = APIRequest()
            BeamDate.freeze("2022-04-18T06:00:03Z")
            Configuration.reset()
        }

        afterEach {
            Configuration.reset()
            BeamDate.reset()
        }

        describe("GraphQL requests (remote API disabled)") {
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

            context("Foundation performRequest") {
                it("throws networkUnavailable immediately") {
                    expect {
                        _ = try self.sut.performRequest(bodyParamsRequest: bodyParamsRequest,
                                                        authenticatedCall: false) { (_: Swift.Result<ForgotPassword, Error>) in
                            fail("completion must not run")
                        }
                    }.to(throwError { (error: APIRequestError) in
                        expect(error).to(matchError(APIRequestError.networkUnavailable))
                    })
                }
            }

            context("async performRequest") {
                asyncIt("throws networkUnavailable") {
                    do {
                        let _: ForgotPassword = try await self.sut.performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                                  authenticatedCall: false)
                        fail("expected networkUnavailable")
                    } catch {
                        expect(error).to(matchError(APIRequestError.networkUnavailable))
                    }
                }
            }
        }
    }
}
