import Foundation
import XCTest
import Quick
import Nimble
import PromiseKit
import Promises

@testable import Beam
class DocumentRequestTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        // MARK: Properties
        var coreDataManager: CoreDataManager!
        var sut: DocumentRequest!
        var helper: DocumentManagerTestsHelper!
        let beamHelper = BeamTestsHelper()

        beforeSuite {
            coreDataManager = CoreDataManager()
            // Setup CoreData
            coreDataManager.setup()
            CoreDataManager.shared = coreDataManager
            sut = DocumentRequest()
            let documentManager = DocumentManager(coreDataManager: coreDataManager)

            helper = DocumentManagerTestsHelper(documentManager: documentManager,
                                                coreDataManager: coreDataManager)
        }

        beforeEach {
            beamHelper.beginNetworkRecording()
            /*
             I enforce logout, to make sure we login after and log that call to network stubs.

             If we don't logout:
             when running the full suite of tests, login was already called before and the network
             call isn't happening again
             then when running only this test, it fails because the login API call wasn't recorded
             and it doesn't match the cassette
             */
            BeamTestsHelper.logout()
            BeamTestsHelper.login()
        }

        afterEach {
            beamHelper.endNetworkRecording()
        }

        describe(".fetchDocument") {
            var docStruct: DocumentStruct!

            context("with existing document") {
                let ancestor = "1\n2\n3"

                beforeEach {
                    docStruct = try! helper.createLocalAndRemoteVersions(ancestor,
                                                                         "995d94e1-e0df-4eca-93e6-8778984bcd18")
                }

                afterEach {
                    helper.deleteDocumentStruct(docStruct)
                }

                context("with Foundation") {
                    it("fetches document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.fetchDocument(docStruct.uuidString) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get().id }.to(equal(docStruct.uuidString))
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                                done()
                            }
                        }
                    }
                }
                context("with PromiseKit") {
                    it("fetches document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<DocumentAPIType> = sut.fetchDocument(docStruct.uuidString)
                            promise
                                .done { result in
                                    expect(result.id) == docStruct.uuidString
                                    done()
                                }
                                .catch { fail("Should not be called: \($0)"); done() }
                        }
                    }
                }
                context("with Promises") {
                    it("fetches document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<DocumentAPIType> = sut.fetchDocument(docStruct.uuidString)
                            promise
                                .then { result in
                                    expect(result.id) == docStruct.uuidString
                                    done()
                                }
                                .catch { fail("Should not be called: \($0)"); done() }
                        }
                    }
                }
            }

            context("with non existing document") {
                let nonExistingUUID = "995d94e1-e0df-4eca-93e6-8778984bffff"

                context("with Foundation") {
                    it("fetches document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.fetchDocument(nonExistingUUID) { result in
                                    expect { try result.get() }.to(throwError { error in
                                        expect(error).to(matchError(APIRequestError.notFound))
                                    })
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                                done()
                            }
                        }
                    }
                }
                context("with PromiseKit") {
                    it("fetches document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<DocumentAPIType> = sut.fetchDocument(nonExistingUUID)
                            promise
                                .done { _ in
                                    fail("Should not be called")
                                    done()
                                }
                                .catch { error in
                                    expect(error).to(matchError(APIRequestError.notFound))
                                    done()
                                }
                        }
                    }
                }
                context("with Promises") {
                    it("fetches document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<DocumentAPIType> = sut.fetchDocument(nonExistingUUID)
                            promise
                                .then { _ in
                                    fail("Should not be called")
                                    done()
                                } .catch { error in
                                    expect(error).to(matchError(APIRequestError.notFound))
                                    done()
                                }
                        }
                    }
                }
            }
        }
    }
}
