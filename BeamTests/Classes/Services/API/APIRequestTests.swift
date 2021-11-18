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
        let beamObjectHelper = BeamObjectTestsHelper()

        beforeEach {
            self.sut = APIRequest()
            Configuration.reset()
        }

        afterEach {
            Configuration.reset()
            beamHelper.endNetworkRecording()
        }

        describe("performRequest()") {
            context("with files") {
                context("with Foundation") {
                    let uuid = "295d94e1-e0df-4eca-93e6-8778984bcd58".uuid!
                    let fixedDate = "2021-03-19T12:21:03Z"

                    beforeEach {
                        BeamDate.freeze(fixedDate)

                        BeamTestsHelper.logout()
                        try? EncryptionManager.shared.replacePrivateKey(Configuration.testPrivateKey)

                        BeamURLSession.shouldNotBeVinyled = true
                        beamHelper.beginNetworkRecording()
                        BeamTestsHelper.login()
                    }

                    afterEach {
                        let semaphore = DispatchSemaphore(value: 0)
                        _ = try? BeamObjectManager().delete(uuid) { _ in
                            semaphore.signal()
                        }

                        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
                        if case .timedOut = semaResult {
                            fail("Timedout")
                        }
                    }

                    fit("upload multipart data") {
                        let object = MyRemoteObject(beamObjectId: uuid,
                                                    createdAt: BeamDate.now,
                                                    updatedAt: BeamDate.now,
                                                    deletedAt: nil,
                                                    previousChecksum: nil,
                                                    checksum: nil,
                                                    title: "foobar")

                        let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                        try beamObject.encrypt()

                        struct LargeFileBeamObjectWithPrivateKey: Codable {
                            var id: UUID
                            var data: Data?
                            var checksum: String?
                            var privateKeySignature: String?
                            var type: String
                            var createdAt: Date
                            var updatedAt: Date
                            var privateKey: String
                        }

                        let largeFileObject = LargeFileBeamObjectWithPrivateKey(id: object.beamObjectId,
                                                                                data: object.previousData,
                                                                                checksum: beamObject.dataChecksum,
                                                                                privateKeySignature: beamObject.privateKeySignature,
                                                                                type: beamObject.beamObjectType,
                                                                                createdAt: object.createdAt,
                                                                                updatedAt: object.updatedAt,
                                                                                privateKey: EncryptionManager.shared.privateKey().asString())

                        // Multipart version of the encrypted object
                        let fileUpload = GraphqlFileUpload(contentType: "application/octet-stream",
                                                           binary: beamObject.data!,
                                                           filename: "\(uuid).enc",
                                                           variableName: "data")

                        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_object_large",
                                                                  variables: beamObject,
                                                                  files: [fileUpload])

                        waitUntil(timeout: .seconds(10)) { done in
                            _ = try? self.sut.performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Swift.Result<BeamObjectRequest.UpdateBeamObject, Error>) in

                                switch result {
                                case .success: break
                                case .failure(let error):
                                    dump(error)
                                }

                                let updateBeamObject = try? result.get()

                                expect { try result.get() }.toNot(throwError())
                                expect(updateBeamObject?.beamObject).toNot(beNil())
                                expect(updateBeamObject?.beamObject?.id) == uuid
                                done()
                            }
                        }

                        let remoteObject = beamObjectHelper.fetchOnAPI(uuid)

                        try beamObject.decrypt()
                        expect(remoteObject?.createdAt?.intValue) == beamObject.createdAt?.intValue
                        expect(remoteObject?.data) == beamObject.data
                    }
                }
            }
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
                    waitUntil(timeout: .seconds(10)) { [unowned self] done in
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
