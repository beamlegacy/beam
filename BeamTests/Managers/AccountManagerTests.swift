import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
class AccountManagerTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        let sut = AccountManager()
        let existingAccountEmail = "fabien+test@beamapp.co"

        // I filter those kind of messages in my box to be deleted right away
        let nonExistingAccountEmail = "fabien+test-\(UUID())@beamapp.co"

        beforeEach {
            AccountManager.logout()
        }

        describe(".forgotPassword") {
            context("with existing account") {
                it("returns") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.forgotPassword(email: existingAccountEmail) { result in
                            expect { try result.get() }.toNot(throwError())
                            done()
                        }
                    }
                }
            }

            context("with non-existing account") {
                it("returns") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.forgotPassword(email: nonExistingAccountEmail) { result in
                            expect { try result.get() }.toNot(throwError())
                            done()
                        }
                    }
                }
            }
        }

        describe(".signUp()") {
            let password = randomString(length: 12)

            context("with existing account") {
                it("returns an error") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.signUp(existingAccountEmail, password) { result in
                            expect { try result.get() }.to(throwError { (error: APIRequestError) in
                                expect(error.errorDescription).to(equal("A user already exists with this email"))
                            })
                            done()
                        }
                    }
                }
            }

            context("with non-existing account") {
                it("doesn't return an error") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.signUp(nonExistingAccountEmail, password) { result in
                            expect { try result.get() }.toNot(throwError())
                            done()
                        }
                    }
                }
            }
        }

        describe(".signIn()") {
            context("with good password") {
                let password = Configuration.testAccountPassword

                it("authenticates") {
                    expect(sut.loggedIn).to(beFalse())
                    self.login(sut, existingAccountEmail, password)
                    expect(sut.loggedIn).to(beTrue())
                }
            }

            context("with wrong password") {
                let password = "wrong password"

                it("doesn't authenticate") {
                    expect(sut.loggedIn).to(beFalse())
                    self.login(sut, existingAccountEmail, password)
                    expect(sut.loggedIn).to(beFalse())
                }
            }
        }
    }

    private func login(_ sut: AccountManager, _ email: String, _ password: String) {
        guard !AuthenticationManager.shared.isAuthenticated else { return }

        waitUntil(timeout: .seconds(10)) { done in
            sut.signIn(email, password) { _ in
                done()
            }
        }
    }

    private func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map { _ in letters.randomElement()! })
    }
}
