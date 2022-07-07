//
//  BeamAccount+RemoteServer+DeleteAccountTests.swift
//  BeamTests
//
//  Created by Jérôme Blondon on 02/06/2022.
//

import XCTest
import Quick
import Nimble

@testable import Beam
@testable import BeamCore

//class BeamAccountDeleteAccountTests: QuickSpec, BeamDocumentSource {
//    static var sourceId: String { "\(Self.self)" }
//    override func spec() {
//        let beamHelper = BeamTestsHelper()
//        let basePath = "test-\(UUID())"
//
//        guard let sut = try? BeamAccount(id: UUID(), email: "test@beamapp.co", name: "test", path: basePath) else {
//            fail("Couldn't create test BeamAccount")
//            return
//        }
//
//        afterSuite {
//            do {
//                try sut.delete(self)
//            } catch {
//                fail(error.localizedDescription)
//            }
//        }
//
//        beforeEach { _ in
//            BeamDate.freeze("2022-04-18T06:00:03Z")
//            BeamTestsHelper.logout()
//
//            Configuration.setAPIEndPointsToStaging()
//            beamHelper.beginNetworkRecording()
//        }
//
//        afterEach {
//            BeamTestsHelper.logout()
//            beamHelper.endNetworkRecording()
//            BeamDate.reset()
//            Configuration.reset()
//        }
//
//        describe(".deleteAccount()") {
//
//            context("with Foundation") {
//                context("with existing accounts") {
//                    let randomString = UUID()
//                    let emailComponents = Configuration.testAccountEmail.split(separator: "@")
//                    let email = "\(emailComponents[0])_\(randomString)@\(emailComponents[1])"
//                    let username = "\(emailComponents[0])_\(randomString)".replacingOccurrences(of: "+", with: "_").substring(from: 0, to: 30)
//                    let password = Configuration.testAccountPassword
//
//                    it("returns true") {
//                        waitUntil(timeout: .seconds(60)) { done in
//                            sut.signUp(email, password) { result in
//                                if case .failure(let error) = result {
//                                    fail(error.localizedDescription)
//                                }
//                                expect { try result.get() } == true
//                                done()
//                            }
//                        }
//
//                        waitUntil(timeout: .seconds(60)) { done in
//                            sut.signIn(email: email, password: password, runFirstSync: false, completionHandler: { result in
//                                if case .failure(let error) = result {
//                                    fail(error.localizedDescription)
//                                }
//                                expect { try result.get() } == true
//                                done()
//                            })
//                        }
//
//                        waitUntil(timeout: .seconds(60)) { done in
//                            sut.setUsername(username: username) { result in
//                                if case .failure(let error) = result {
//                                    fail(error.localizedDescription)
//                                }
//                                done()
//                            }
//                        }
//
//                        waitUntil(timeout: .seconds(60)) { done in
//                            sut.deleteAccount { result in
//                                if case .failure(let error) = result {
//                                    fail(error.localizedDescription)
//                                }
//                                expect { try result.get() } == true
//                                done()
//                            }
//                        }
//                    }
//                }
//            }
//        }
//    }
//}
