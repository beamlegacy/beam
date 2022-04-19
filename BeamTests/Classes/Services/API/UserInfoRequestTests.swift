//
//  UserInfoRequestTests.swift
//  BeamTests
//
//  Created by Remi Santos on 13/12/2021.
//

import XCTest
import Quick
import Nimble
import Promises
@testable import Beam
@testable import BeamCore

class UserInfoRequestTests: QuickSpec {
    override func spec() {
        let beamHelper = BeamTestsHelper()
        var sut: UserInfoRequest!

        var availableUsername: String = ""
        let nonAvailableUsername = "beam"
        
        let currentPassword = Configuration.testAccountPassword
        let newPassword = "nC28!%*qLB^W"
        
        beforeEach {
            availableUsername = String("UIRTests-\(UUID())".prefix(29))
            sut = UserInfoRequest()
            BeamDate.freeze("2022-04-18T06:00:03Z")
            BeamTestsHelper.logout()
            beamHelper.beginNetworkRecording()
            BeamTestsHelper.login()
        }

        afterEach {
            BeamTestsHelper.logout()
            beamHelper.endNetworkRecording()
            BeamDate.reset()
        }

        describe(".setUsername") {
            context("with Foundation") {
                context("with available username") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? sut.setUsername(username: availableUsername) { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }
                    }
                }

                context("with non-available username") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? sut.setUsername(username: nonAvailableUsername) { result in
                                expect { try result.get() }.to(throwError { (error: APIRequestError) in
                                    let errorable = UserInfoRequest.UpdateMe(
                                        me: nil,
                                        errors: [UserErrorData(message: "Username has already been taken", path: nil)]
                                    )
                                    expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                                })
                                done()
                            }
                        }
                    }
                }
            }

            context("with Promises") {
                context("with available username") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<UserInfoRequest.UpdateMe> = sut
                                .setUsername(username: availableUsername)

                            promise.then { result in
                                expect(result.me?.username).toNot(beEmpty())
                                done()
                            }
                            .catch { fail("Couldn't set username: \(availableUsername) - \($0)"); done() }
                        }
                    }
                }

                context("with non-existing account") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<UserInfoRequest.UpdateMe> = sut
                                .setUsername(username: nonAvailableUsername)

                            promise.then { _ in }
                            .catch { error in
                                expect(error).to(beAnInstanceOf(APIRequestError.self))
                                let errorable = UserInfoRequest.UpdateMe(
                                    me: nil,
                                    errors: [UserErrorData(message: "Username has already been taken", path: nil)]
                                )
                                expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                                done()
                            }
                        }
                    }
                }
            }
        }

        describe(".updatePassword") {
            context("with Foundation") {
                context("with validParameters") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? sut.updatePassword(currentPassword: currentPassword, newPassword: newPassword) { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }

                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? sut.updatePassword(currentPassword: newPassword, newPassword: currentPassword) { result in
                                expect { try result.get() }.toNot(throwError())
                                done()
                            }
                        }
                    }
                }

                context("with invalid current password") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? sut.updatePassword(currentPassword: "totally wrong password", newPassword: newPassword) { result in
                                expect { try result.get() }.to(throwError { (error: APIRequestError) in
                                    let errorable = UserInfoRequest.UpdatePassword(
                                        success: nil,
                                        errors: [UserErrorData(message: "Invalid password", path: ["parameters", "password"], code: .passwordInvalid)]
                                    )
                                    expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                                })
                                done()
                            }
                        }
                    }
                }

                context("with invalid new password") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionDataTask? = try? sut.updatePassword(currentPassword: currentPassword, newPassword: "t") { result in
                                expect { try result.get() }.to(throwError { (error: APIRequestError) in
                                    let errorable = UserInfoRequest.UpdatePassword(
                                        success:  nil,
                                        errors: [UserErrorData(message: "Password is too short (minimum is 6 characters)", path: ["attribute", "password"])]
                                    )
                                    expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                                })
                                done()
                            }
                        }
                    }
                }
            }
        }
    }
}
