import XCTest
import Quick
import Nimble
import Promises
@testable import Beam
@testable import BeamCore

class AccountManagerDeletAccountTests: QuickSpec {
    override func spec() {
        let beamHelper = BeamTestsHelper()
        let sut = AccountManager()

        beforeEach { _ in
            BeamDate.freeze("2022-04-18T06:00:03Z")
            BeamTestsHelper.logout()

            Configuration.setAPIEndPointsToStaging()
            beamHelper.beginNetworkRecording()
        }

        afterEach {
            BeamTestsHelper.logout()
            beamHelper.endNetworkRecording()
            BeamDate.reset()
            Configuration.reset()
        }

        describe(".deleteAccount()") {

            context("with Foundation") {
                context("with existing accounts") {
                    let email = "jbl+test-\(UUID())@beamapp.co"
                    let password = "nC18!%*qLB^W"

                    it("returns true") {
                        waitUntil(timeout: .seconds(60)) { done in
                            sut.signUp(email, password) { result in
                                if case .failure(let error) = result {
                                    fail(error.localizedDescription)
                                }
                                expect { try result.get() } == true
                                done()
                            }
                        }

                        waitUntil(timeout: .seconds(60)) { done in
                            sut.signIn(email: email, password: password, runFirstSync: false, completionHandler: { result in
                                if case .failure(let error) = result {
                                    fail(error.localizedDescription)
                                }
                                expect { try result.get() } == true
                                done()
                            })
                        }

                        waitUntil(timeout: .seconds(60)) { done in
                            sut.deleteAccount { result in
                                if case .failure(let error) = result {
                                    fail(error.localizedDescription)
                                }
                                expect { try result.get() } == true
                                done()
                            }
                        }
                    }
                }
            }
        }

    }
}
