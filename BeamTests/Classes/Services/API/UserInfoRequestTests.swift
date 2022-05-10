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
                    asyncIt("returns") {
                        do {
                            let result = try await sut.setUsername(username: availableUsername)
                            expect(result.errors).to(beEmpty())
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }

                context("with non-available username") {
                    asyncIt("returns") {
                        do {
                            try await sut.setUsername(username: nonAvailableUsername)
                            fail("Should not happen")
                        } catch {
                            let errorable = UserInfoRequest.UpdateMe(
                                me: nil,
                                errors: [UserErrorData(message: "Username has already been taken", path: nil)]
                            )
                            expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
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
                    asyncIt("returns") {
                        do {
                            let result = try await sut.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
                            expect(result.success).to(beTrue())
                        } catch {
                            fail(error.localizedDescription)
                        }

                        do {
                            let result = try await sut.updatePassword(currentPassword: newPassword, newPassword: currentPassword)
                            expect(result.success).to(beTrue())
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }

                context("with invalid current password") {
                    asyncIt("returns") {
                        do {
                            try await sut.updatePassword(currentPassword: "totally wrong password", newPassword: newPassword)
                            fail("Should not happen")
                        } catch {
                            let errorable = UserInfoRequest.UpdatePassword(
                                success: nil,
                                errors: [UserErrorData(message: "Invalid password", path: ["parameters", "password"], code: .passwordInvalid)]
                            )
                            expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                        }
                    }
                }

                context("with invalid new password") {
                    asyncIt("returns") {
                        do {
                            try await sut.updatePassword(currentPassword: currentPassword, newPassword: "t")
                            fail("Should not happen")
                        } catch {
                            let errorable = UserInfoRequest.UpdatePassword(
                                success:  nil,
                                errors: [UserErrorData(message: "Password is too short (minimum is 6 characters)", path: ["attribute", "password"])]
                            )
                            expect(error).to(matchError(APIRequestError.apiErrors(errorable)))
                        }
                    }
                }
            }
        }
    }
}
