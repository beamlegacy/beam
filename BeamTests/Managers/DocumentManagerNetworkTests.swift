// swiftlint:disable file_length

import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import Promises
import PromiseKit
import PMKFoundation

@testable import Beam
// swiftlint:disable:next type_body_length
class DocumentManagerNetworkTests: QuickSpec {
    lazy var coreDataManager = {
        CoreDataManager()
    }()
    lazy var mainContext = {
        coreDataManager.mainContext
    }()

    // swiftlint:disable:next function_body_length
    override func spec() {
        // MARK: Properties
        var sut: DocumentManager!
        var helper: DocumentManagerTestsHelper!

        beforeEach {
            BeamTestsHelper.login()
        }

        afterEach {
            sut.clearNetworkCalls()
        }

        beforeSuite {
            // Setup CoreData
            self.coreDataManager.setup()
            CoreDataManager.shared = self.coreDataManager
            sut = DocumentManager(coreDataManager: self.coreDataManager)
            helper = DocumentManagerTestsHelper(documentManager: sut,
                                                     coreDataManager: self.coreDataManager)

            // Try to avoid issues with BeamTextTests creating documents when parsing links
            BeamNote.clearCancellables()
        }

        afterSuite {
            BeamTestsHelper.logout()
        }

        describe(".refreshDocuments()") {
            var docStruct: DocumentStruct!
            afterEach {
                // Not to leave any on the server
                helper.deleteDocumentStruct(docStruct)
            }

            context("when remote has the same updatedAt") {
                beforeEach {
                    BeamDate.freeze()
                    docStruct = helper.createDocumentStruct()
                    helper.saveLocally(docStruct)
                    helper.saveRemotely(docStruct)
                }

                afterEach {
                    BeamDate.reset()
                }

                it("refreshes the local document") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.refreshDocuments { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() }.to(beTrue())
                            expect(APIRequest.callsCount - networkCalls) >= 1
                            done()
                        }
                    }
                }
            }

            context("when remote document doesn't exist") {
                beforeEach {
                    docStruct = helper.createDocumentStruct()
                    helper.saveLocally(docStruct)
                }

                it("flags the local document as deleted") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.refreshDocuments { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() }.to(beTrue())
                            expect(APIRequest.callsCount - networkCalls) >= 1
                            done()
                        }
                    }

                    let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                    expect(newDocStruct).toNot(beNil())
                    expect(newDocStruct?.deletedAt).to(beCloseTo(BeamDate.now, within: 1.0))

                    let document = Document.fetchWithId(self.mainContext, docStruct.id)
                    expect(document?.deleted_at).toNot(beNil())
                }
            }

            context("when remote has a more recent updatedAt") {
                context("without conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4"
                    beforeEach {
                        docStruct = helper.createLocalAndRemoteVersions(ancestor, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("refreshes the local document") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.refreshDocuments { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() }.to(beTrue())
                                expect(APIRequest.callsCount - networkCalls).to(equal(1))
                                done()
                            }
                        }
                        let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                        expect(newDocStruct?.data).to(equal(newRemote.asData))
                    }
                }

                context("with conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4\n"
                    let newLocal = "0\n1\n2\n3"
                    let merged = "0\n1\n2\n3\n4\n"

                    beforeEach {
                        docStruct = helper.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("refreshes the local document") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.refreshDocuments { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() }.to(beTrue())
                                expect(APIRequest.callsCount - networkCalls).to(equal(1))
                                done()
                            }
                        }

                        let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                        expect(newDocStruct?.data.asString).to(equal(merged))
                    }
                }
            }

            context("with non mergeable conflict") {
                let ancestor = "1\n2\n3\n"
                let newRemote = "0\n2\n3\n"
                let newLocal = "2\n2\n3\n"

                beforeEach {
                    docStruct = helper.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                }

                afterEach {
                    BeamDate.reset()
                }

                it("doesn't update the local document, returns error") {
                    let networkCalls = APIRequest.callsCount
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.refreshDocuments { result in
                            expect { try result.get() }.to(throwError { (error: DocumentManagerError) in
                                expect(error).to(equal(DocumentManagerError.unresolvedConflict))
                            })
                            expect(APIRequest.callsCount - networkCalls).to(equal(1))
                            done()
                        }
                    }

                    let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                    expect(newDocStruct?.data.asString).to(equal(newLocal))
                }
            }
        }

        describe(".refreshDocument()") {
            var docStruct: DocumentStruct!
            var networkCalls: Int!

            afterEach {
                // Not to leave any on the server
                helper.deleteDocumentStruct(docStruct)
            }

            context("when remote has the same updatedAt") {
                beforeEach {
                    BeamDate.freeze()
                    docStruct = helper.createDocumentStruct()
                    helper.saveLocally(docStruct)
                    helper.saveRemotely(docStruct)
                    networkCalls = APIRequest.callsCount
                }

                afterEach {
                    BeamDate.reset()
                }

                context("with Foundation") {
                    it("doesn't refresh the local document") {
                        expect(AuthenticationManager.shared.isAuthenticated).to(beTrue())
                        expect(Configuration.networkEnabled).to(beTrue())

                        waitUntil(timeout: .seconds(10)) { done in
                            sut.refreshDocument(docStruct) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() }.to(beFalse())
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls).to(equal(1))
                    }
                }

                context("with PromiseKit") {
                    it("doesn't refresh the local document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.refreshDocument(docStruct)
                            promise.done { refreshed in
                                expect(refreshed).to(beFalse())
                                done()
                            }.catch { _ in }
                        }

                        expect(APIRequest.callsCount - networkCalls).to(equal(1))
                    }
                }

                context("with Promises") {
                    it("doesn't refresh the local document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.refreshDocument(docStruct)
                            promise.then { refreshed in
                                expect(refreshed).to(beFalse())
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls).to(equal(1))
                    }
                }
            }

            context("when remote has a more recent updatedAt") {
                context("without conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4"

                    beforeEach {
                        docStruct = helper.createLocalAndRemoteVersions(ancestor, newRemote: newRemote)
                        networkCalls = APIRequest.callsCount
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    context("with PromiseKit") {
                        it("refreshes the local document") {
                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: PromiseKit.Promise<Bool> = sut.refreshDocument(docStruct)
                                promise.done { refreshed in
                                    expect(refreshed).to(beTrue())
                                    done()
                                }.catch { _ in }
                            }

                            expect(APIRequest.callsCount - networkCalls).to(equal(2))

                            let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                            expect(newDocStruct?.data).to(equal(newRemote.asData))
                        }
                    }

                    context("with Promises") {
                        it("refreshes the local document") {
                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: Promises.Promise<Bool> = sut.refreshDocument(docStruct)
                                promise.then { refreshed in
                                    expect(refreshed).to(beTrue())
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls).to(equal(2))

                            let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                            expect(newDocStruct?.data).to(equal(newRemote.asData))
                        }
                    }
                }

                context("with conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4\n"
                    let newLocal = "0\n1\n2\n3"
                    let merged = "0\n1\n2\n3\n4\n"

                    beforeEach {
                        docStruct = helper.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    context("with PromiseKit") {
                        it("refreshes the local document") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: PromiseKit.Promise<Bool> = sut.refreshDocument(docStruct)
                                promise.done { refreshed in
                                    expect(refreshed).to(beTrue())
                                    done()
                                }.catch { _ in }
                            }

                            expect([2, 5]).to(contain(APIRequest.callsCount - networkCalls))

                            let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                            expect(newDocStruct?.data.asString).to(equal(merged))
                        }
                    }

                    context("with Promises") {
                        it("refreshes the local document") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: Promises.Promise<Bool> = sut.refreshDocument(docStruct)
                                promise.then { refreshed in
                                    expect(refreshed).to(beTrue())
                                    done()
                                }
                            }

                            expect([2, 5]).to(contain(APIRequest.callsCount - networkCalls))

                            let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                            expect(newDocStruct?.data.asString).to(equal(merged))
                        }
                    }
                }
            }

            context("when remote document doesn't exist") {
                beforeEach {
                    docStruct = helper.createDocumentStruct()
                    helper.saveLocally(docStruct)
                    networkCalls = APIRequest.callsCount
                }

                context("with PromiseKit") {
                    it("doesn't refresh the local document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.refreshDocument(docStruct)
                            promise
                                .done { _ in }
                                .catch { error in
                                    expect(error).to(matchError(APIRequestError.notFound))
                                    done()
                                }
                        }

                        expect(APIRequest.callsCount - networkCalls).to(equal(1))

                        let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                        expect(newDocStruct?.deletedAt).toNot(beNil())
                    }
                }

                context("with Promises") {
                    it("doesn't refresh the local document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.refreshDocument(docStruct)
                            promise
                                .then { _ in }
                                .catch { error in
                                    expect(error).to(matchError(APIRequestError.notFound))
                                    done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls).to(equal(1))

                        let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                        expect(newDocStruct?.deletedAt).toNot(beNil())
                    }
                }
            }
        }

        describe(".saveDocument()") {
            var docStruct: DocumentStruct!
            beforeEach {
                docStruct = helper.createDocumentStruct()
            }
            afterEach {
                // Not to leave any on the server
                helper.deleteDocumentStruct(docStruct)
            }

            context("with network") {
                context("without conflict") {
                    it("saves the document locally") {
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.saveDocument(docStruct) { _ in
                                done()
                            }
                        }

                        let count = Document.countWithPredicate(self.mainContext,
                                                                NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                        expect(count).to(equal(1))
                    }

                    context("with Foundation") {
                        beforeEach {
                            helper.saveLocally(docStruct)
                        }

                        it("saves the document on the API") {
                            waitUntil(timeout: .seconds(10)) { done in
                                sut.saveDocumentStructOnAPI(docStruct) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() }.to(beTrue())
                                    done()
                                }
                            }

                            expect(helper.fetchOnAPI(docStruct)?.id).to(equal(docStruct.uuidString))
                        }

                        it("cancels previous unfinished saves") {
                            let previousNetworkCall = APIRequest.callsCount
                            let times = 10
                            let title = docStruct.title
                            var newTitle = title

                            for index in 0..<times {
                                newTitle = "\(title) - \(index)"
                                docStruct.title = newTitle
                                sut.saveDocumentStructOnAPI(docStruct) { result in
                                    expect { try result.get() }.to(throwError { (error: NSError) in
                                        expect(error.code) == NSURLErrorCancelled
                                    })
                                }
                            }

                            newTitle = "\(title) - last"
                            waitUntil(timeout: .seconds(10)) { done in
                                docStruct.title = newTitle
                                sut.saveDocumentStructOnAPI(docStruct) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() } == true
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - previousNetworkCall) == 1

                            let remoteStruct = helper.fetchOnAPI(docStruct)
                            expect(remoteStruct?.title) == newTitle
                        }
                    }

                    context("with PromiseKit") {
                        beforeEach {
                            helper.saveLocally(docStruct)
                        }

                        it("saves the document on the API") {
                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: PromiseKit.Promise<Bool> = sut.saveDocumentOnApi(docStruct)
                                promise.done { success in
                                    expect(success) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)") }
                            }

                            expect(helper.fetchOnAPI(docStruct)?.id).to(equal(docStruct.uuidString))
                        }

                        it("cancels previous unfinished saves") {
                            let previousNetworkCall = APIRequest.callsCount
                            let times = 10
                            let title = docStruct.title
                            var newTitle = title

                            for index in 0..<times {
                                newTitle = "\(title) - \(index)"
                                docStruct.title = newTitle
                                let promise: PromiseKit.Promise<Bool> = sut.saveDocumentOnApi(docStruct)
                                promise.done {
                                    fail("Should not be called: \($0)")
                                }.catch { error in
                                    expect(error).to(matchError(DocumentManagerError.operationCancelled))
                                }
                            }

                            newTitle = "\(title) - last"
                            waitUntil(timeout: .seconds(10)) { done in
                                docStruct.title = newTitle
                                let promise: PromiseKit.Promise<Bool> = sut.saveDocumentOnApi(docStruct)
                                promise.done { success in
                                    expect(success) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)") }
                            }

                            expect(APIRequest.callsCount - previousNetworkCall) == 1

                            let remoteStruct = helper.fetchOnAPI(docStruct)
                            expect(remoteStruct?.title) == newTitle
                        }
                    }

                    context("with Promises") {
                        beforeEach {
                            helper.saveLocally(docStruct)
                        }

                        it("saves the document on the API") {
                            let promise: Promises.Promise<Bool> = sut.saveDocumentOnApi(docStruct)

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { success in
                                    expect(success) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)") }
                            }

                            expect(helper.fetchOnAPI(docStruct)?.id).to(equal(docStruct.uuidString))
                        }

                        it("cancels previous unfinished saves") {
                            let previousNetworkCall = APIRequest.callsCount
                            let times = 10
                            let title = docStruct.title
                            var newTitle = title

                            for index in 0..<times {
                                newTitle = "\(title) - \(index)"
                                docStruct.title = newTitle
                                let promise: Promises.Promise<Bool> = sut.saveDocumentOnApi(docStruct)
                                promise.then {
                                    fail("Should not be called: \($0)")
                                }.catch { error in
                                    expect(error).to(matchError(DocumentManagerError.operationCancelled))
                                }
                            }

                            newTitle = "\(title) - last"
                            waitUntil(timeout: .seconds(10)) { done in
                                docStruct.title = newTitle
                                let promise: Promises.Promise<Bool> = sut.saveDocumentOnApi(docStruct)
                                promise.then { success in
                                    expect(success) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)") }
                            }

                            expect(APIRequest.callsCount - previousNetworkCall) == 1

                            let remoteStruct = helper.fetchOnAPI(docStruct)
                            expect(remoteStruct?.title) == newTitle
                        }
                    }
                }

                context("with non mergeable conflict") {
                    let ancestor = "1\n2\n3\n"
                    let newRemote = "0\n2\n3\n"
                    let newLocal = "2\n2\n3\n"

                    beforeEach {
                        docStruct = helper.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    context("with Foundation") {
                        it("updates the remote document with the local version") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                sut.saveDocumentStructOnAPI(docStruct) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() }.to(beTrue())

                                    // When this is failing randomly, rerun. This is because of the way
                                    // `BeamNote` saves document looking for links
                                    expect(APIRequest.callsCount - networkCalls).to(equal(3))
                                    done()
                                }
                            }

                            let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                            expect(newDocStruct?.data.asString).to(equal(newLocal))
                            expect(helper.fetchOnAPIWithLatency(docStruct, newLocal)) == true
                        }
                    }

                    context("with PromiseKit") {
                        it("updates the remote document with the local version") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: PromiseKit.Promise<Bool> = sut.saveDocumentOnApi(docStruct)

                                promise.done { success in
                                    expect(success) == true
                                    done()
                                }.catch { error in
                                    fail("Error: \(error)")
                                }
                            }

                            // When this is failing randomly, rerun. This is because of the way
                            // `BeamNote` saves document looking for links
                            expect(APIRequest.callsCount - networkCalls).to(equal(3))

                            let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                            expect(newDocStruct?.data.asString).to(equal(newLocal))
                            expect(helper.fetchOnAPIWithLatency(docStruct, newLocal)) == true
                        }
                    }

                    context("with Promises") {
                        it("updates the remote document with the local version") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: Promises.Promise<Bool> = sut.saveDocumentOnApi(docStruct)

                                promise.then { success in
                                    expect(success) == true
                                    done()
                                }.catch {
                                    fail("Error: \($0)")
                                }
                            }

                            // When this is failing randomly, rerun. This is because of the way
                            // `BeamNote` saves document looking for links
                            expect(APIRequest.callsCount - networkCalls).to(equal(3))

                            let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                            expect(newDocStruct?.data.asString).to(equal(newLocal))
                            expect(helper.fetchOnAPIWithLatency(docStruct, newLocal)) == true
                        }
                    }
                }

                context("with mergeable conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4\n"
                    let newLocal = "0\n1\n2\n3"
                    let merged = "0\n1\n2\n3\n4\n"

                    beforeEach {
                        docStruct = helper.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    context("with Foundation") {
                        it("updates the remote document") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                sut.saveDocumentStructOnAPI(docStruct) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() }.to(beTrue())
                                    done()
                                }
                            }

                            // We expect 2 calls, but sometimes 5. This is because of the way
                            // `BeamNote` saves document looking for links
                            expect(APIRequest.callsCount - networkCalls) >= 1

                            let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                            expect(newDocStruct?.data.asString).to(equal(merged))
                            expect(helper.fetchOnAPIWithLatency(docStruct, merged)) == true
                        }
                    }

                    context("with PromiseKit") {
                        it("updates the remote document") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: PromiseKit.Promise<Bool> = sut.saveDocumentOnApi(docStruct)

                                promise.done { success in
                                    expect(success) == true
                                    done()
                                }.catch { _ in }
                            }

                            expect(APIRequest.callsCount - networkCalls) >= 1

                            let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                            expect(newDocStruct?.data.asString).to(equal(merged))
                            expect(helper.fetchOnAPIWithLatency(docStruct, merged)) == true
                        }
                    }

                    context("with Promises") {
                        it("updates the remote document") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: Promises.Promise<Bool> = sut.saveDocumentOnApi(docStruct)

                                promise.then { success in
                                    expect(success) == true
                                    done()
                                }.catch { _ in }
                            }

                            expect(APIRequest.callsCount - networkCalls) >= 1

                            let newDocStruct = sut.loadDocumentById(id: docStruct.id)
                            expect(newDocStruct?.data.asString).to(equal(merged))
                            expect(helper.fetchOnAPIWithLatency(docStruct, merged)) == true
                        }
                    }
                }
            }
        }
    }
}
