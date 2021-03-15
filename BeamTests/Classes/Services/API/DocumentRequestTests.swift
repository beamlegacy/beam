import Foundation
import XCTest
import Quick
import Nimble
import PromiseKit
import Promises

@testable import Beam
class DocumentRequestTests: QuickSpec {
    var sut: DocumentRequest!
    var documentManager: DocumentManager!
    var helper: DocumentManagerTestsHelper!
    lazy var coreDataManager = {
        CoreDataManager()
    }()
    lazy var mainContext = {
        coreDataManager.mainContext
    }()

    // swiftlint:disable:next function_body_length
    override func spec() {
        beforeSuite {
            // Setup CoreData
            self.coreDataManager.setup()
            self.coreDataManager.destroyPersistentStore()
            CoreDataManager.shared = self.coreDataManager
            self.sut = DocumentRequest()
            self.documentManager = DocumentManager(coreDataManager: self.coreDataManager)
            self.helper = DocumentManagerTestsHelper(documentManager: self.documentManager,
                                                     coreDataManager: self.coreDataManager)
        }

        beforeEach {
            BeamTestsHelper.login()
        }

        describe(".fetchDocument") {
            var docStruct: DocumentStruct!

            context("with existing Document") {
                let ancestor = "1\n2\n3"

                beforeEach {
                    docStruct = try? self.helper.createLocalAndRemoteVersions(ancestor)
                }

                afterEach {
                    // Not to leave any on the server
                    self.helper.deleteDocumentStruct(docStruct)
                }
                context("with Foundation") {
                    it("fetches document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            _ = try? self.sut.fetchDocument(docStruct.uuidString) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get().id }.to(equal(docStruct.uuidString))
                                done()
                            }
                        }
                    }
                }
                context("with PromiseKit") {
                    it("fetches document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<DocumentAPIType> = self.sut.fetchDocument(docStruct.uuidString)
                            promise
                                .done { result in
                                    expect(result.id) == docStruct.uuidString
                                    done()
                                }
                                .catch { _ in }
                        }
                    }
                }
                context("with Promises") {
                    it("fetches document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<DocumentAPIType> = self.sut.fetchDocument(docStruct.uuidString)
                            promise
                                .then { result in
                                    expect(result.id) == docStruct.uuidString
                                    done()
                                }
                                .catch { _ in }
                        }
                    }
                }
            }

            context("with non existing document") {
                context("with Foundation") {
                    it("fetches document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let _: URLSessionTask? = try? self.sut.fetchDocument(UUID().uuidString) { result in
                                expect { try result.get() }.to(throwError { error in
                                    expect(error).to(matchError(APIRequestError.notFound))
                                })
                                done()
                            }
                        }
                    }
                }
                context("with PromiseKit") {
                    it("fetches document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<DocumentAPIType> = self.sut.fetchDocument(docStruct.uuidString)
                            promise
                                .done { _ in }
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
                            let promise: Promises.Promise<DocumentAPIType> = self.sut.fetchDocument(docStruct.uuidString)
                            promise
                                .then { _ in }
                                .catch { error in
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
