//
//  UserInfoRequestTests.swift
//  BeamTests
//
//  Created by Remi Santos on 13/12/2021.
//

import XCTest
import Quick
import Nimble
import PromiseKit
import Promises
@testable import Beam

class UserInfoRequestTests: QuickSpec {
    override func spec() {
        let beamHelper = BeamTestsHelper()
        var sut: UserInfoRequest!

        var availableUsername: String = ""
        let nonAvailableUsername = "beam"

        beforeEach {
            availableUsername = String("UIRTests-\(UUID())".prefix(29))
            sut = UserInfoRequest()
            BeamTestsHelper.logout()
            beamHelper.beginNetworkRecording()
            BeamTestsHelper.login()
        }

        afterEach {
            BeamTestsHelper.logout()
            beamHelper.endNetworkRecording()
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

            context("with PromiseKit") {
                context("with available username") {
                    it("returns") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<UserInfoRequest.UpdateMe> = sut
                                .setUsername(username: availableUsername)

                            promise.done { result in
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
                            let promise: PromiseKit.Promise<UserInfoRequest.UpdateMe> = sut
                                .setUsername(username: nonAvailableUsername)

                            promise.done { _ in }
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
    }
}
