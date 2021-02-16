// swiftlint:disable file_length

import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import Alamofire

@testable import Beam
// swiftlint:disable:next type_body_length
class DocumentManagerNetworkTests: QuickSpec {
    // MARK: Properties
    var sut: DocumentManager!
    var helper: DocumentManagerTestsHelper!

    lazy var coreDataManager = {
        CoreDataManager()
    }()
    lazy var mainContext = {
        coreDataManager.mainContext
    }()

    // swiftlint:disable:next function_body_length
    override func spec() {
        beforeEach {
            self.helper.login()
        }

        afterEach {
            self.sut.clearNetworkCalls()
        }

        beforeSuite {
            // Setup CoreData
            self.coreDataManager.setup()
            waitUntil(timeout: .seconds(10)) { done in
                self.coreDataManager.destroyPersistentStore {
                    self.coreDataManager.setup()
                    done()
                }
            }
            CoreDataManager.shared = self.coreDataManager
            self.sut = DocumentManager(coreDataManager: self.coreDataManager)
            self.helper = DocumentManagerTestsHelper(documentManager: self.sut,
                                                     coreDataManager: self.coreDataManager)

            waitUntil(timeout: .seconds(10)) { done in
                self.sut.deleteAllDocuments(includedRemote: false) { _ in
                    done()
                }
            }

            // Try to avoid issues with BeamTextTests creating documents when parsing links
            BeamNote.clearCancellables()
        }

        afterSuite {
            self.helper.logout()
        }

        describe(".refreshDocuments()") {
            var docStruct: DocumentStruct!
            afterEach {
                // Not to leave any on the server
                self.helper.deleteDocumentStruct(docStruct)
            }

            context("when remote has the same updatedAt") {
                beforeEach {
                    BeamDate.freeze()
                    docStruct = self.helper.createDocumentStruct()
                    self.helper.saveLocally(docStruct)
                    self.helper.saveRemotely(docStruct)
                }

                afterEach {
                    BeamDate.reset()
                }

                it("refreshes the local document") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        self.sut.refreshDocuments { result in
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
                    docStruct = self.helper.createDocumentStruct()
                    self.helper.saveLocally(docStruct)
                }

                it("flags the local document as deleted") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        self.sut.refreshDocuments { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() }.to(beTrue())
                            expect(APIRequest.callsCount - networkCalls) >= 1
                            done()
                        }
                    }

                    let newDocStruct = self.sut.loadDocumentById(id: docStruct.id)
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
                        docStruct = self.helper.createLocalAndRemoteVersions(ancestor, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("refreshes the local document") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil(timeout: .seconds(10)) { done in
                            self.sut.refreshDocuments { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() }.to(beTrue())
                                expect(APIRequest.callsCount - networkCalls).to(equal(1))
                                done()
                            }
                        }
                        let newDocStruct = self.sut.loadDocumentById(id: docStruct.id)
                        expect(newDocStruct?.data).to(equal(newRemote.asData))
                    }
                }

                context("with conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4\n"
                    let newLocal = "0\n1\n2\n3"
                    let merged = "0\n1\n2\n3\n4\n"

                    beforeEach {
                        docStruct = self.helper.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("refreshes the local document") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil(timeout: .seconds(10)) { done in
                            self.sut.refreshDocuments { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() }.to(beTrue())
                                expect(APIRequest.callsCount - networkCalls).to(equal(1))
                                done()
                            }
                        }

                        let newDocStruct = self.sut.loadDocumentById(id: docStruct.id)
                        expect(newDocStruct?.data.asString).to(equal(merged))
                    }
                }
            }

            context("with non mergeable conflict") {
                let ancestor = "1\n2\n3\n"
                let newRemote = "0\n2\n3\n"
                let newLocal = "2\n2\n3\n"

                beforeEach {
                    docStruct = self.helper.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                }

                afterEach {
                    BeamDate.reset()
                }

                it("doesn't update the local document, returns error") {
                    let networkCalls = APIRequest.callsCount
                    waitUntil(timeout: .seconds(10)) { done in
                        self.sut.refreshDocuments { result in
                            expect { try result.get() }.to(throwError { (error: DocumentManagerError) in
                                expect(error).to(equal(DocumentManagerError.unresolvedConflict))
                            })
                            expect(APIRequest.callsCount - networkCalls).to(equal(1))
                            done()
                        }
                    }

                    let newDocStruct = self.sut.loadDocumentById(id: docStruct.id)
                    expect(newDocStruct?.data.asString).to(equal(newLocal))
                }
            }
        }

        describe(".refreshDocument()") {
            var docStruct: DocumentStruct!
            afterEach {
                // Not to leave any on the server
                self.helper.deleteDocumentStruct(docStruct)
            }

            context("when remote has the same updatedAt") {
                beforeEach {
                    BeamDate.freeze()
                    docStruct = self.helper.createDocumentStruct()
                    self.helper.saveLocally(docStruct)
                    self.helper.saveRemotely(docStruct)
                }

                afterEach {
                    BeamDate.reset()
                }

                it("doesn't refresh the local document") {
                    let networkCalls = APIRequest.callsCount

                    expect(AuthenticationManager.shared.isAuthenticated).to(beTrue())
                    expect(Configuration.networkEnabled).to(beTrue())

                    waitUntil(timeout: .seconds(10)) { done in
                        self.sut.refreshDocument(docStruct) { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() }.to(beFalse())
                            expect(APIRequest.callsCount - networkCalls).to(equal(1))
                            done()
                        }
                    }
                }
            }

            context("when remote has a more recent updatedAt") {
                context("without conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4"
                    beforeEach {
                        docStruct = self.helper.createLocalAndRemoteVersions(ancestor, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("refreshes the local document") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil(timeout: .seconds(10)) { done in
                            self.sut.refreshDocument(docStruct) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() }.to(beTrue())
                                expect(APIRequest.callsCount - networkCalls).to(equal(2))
                                done()
                            }
                        }
                        let newDocStruct = self.sut.loadDocumentById(id: docStruct.id)
                        expect(newDocStruct?.data).to(equal(newRemote.asData))
                    }
                }

                context("with conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4\n"
                    let newLocal = "0\n1\n2\n3"
                    let merged = "0\n1\n2\n3\n4\n"

                    beforeEach {
                        docStruct = self.helper.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("refreshes the local document") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil(timeout: .seconds(10)) { done in
                            self.sut.refreshDocument(docStruct) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() }.to(beTrue())
                                // We expect 2 calls, but sometimes 5. This is because of the way
                                // `BeamNote` saves document looking for links
                                expect([2, 5]).to(contain(APIRequest.callsCount - networkCalls))
                                done()
                            }
                        }

                        let newDocStruct = self.sut.loadDocumentById(id: docStruct.id)
                        expect(newDocStruct?.data.asString).to(equal(merged))
                    }
                }
            }

            context("when remote document doesn't exist") {
                beforeEach {
                    docStruct = self.helper.createDocumentStruct()
                    self.helper.saveLocally(docStruct)
                }

                it("doesn't refresh the local document") {
                    waitUntil(timeout: .seconds(10)) { done in
                        self.sut.refreshDocument(docStruct) { result in
                            expect { try result.get() }.to(throwError { (error: AFError) in
                                expect(error.responseCode).to(equal(404))
                            })

                            done()
                        }
                    }
                }
            }
        }

        describe(".saveDocument()") {
            var docStruct: DocumentStruct!
            beforeEach {
                docStruct = self.helper.createDocumentStruct()
            }
            afterEach {
                // Not to leave any on the server
                self.helper.deleteDocumentStruct(docStruct)
            }

            context("with network") {
                context("without conflict") {
                    it("saves the document locally") {
                        waitUntil(timeout: .seconds(10)) { done in
                            self.sut.saveDocument(docStruct) { _ in
                                done()
                            }
                        }

                        let count = Document.countWithPredicate(self.mainContext,
                                                                NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                        expect(count).to(equal(1))
                    }

                    it("saves the document on the API") {
                        self.helper.saveLocally(docStruct)

                        waitUntil(timeout: .seconds(10)) { done in
                            self.sut.saveDocumentStructOnAPI(docStruct) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() }.to(beTrue())
                                done()
                            }
                        }

                        expect(self.helper.fetchOnAPI(docStruct)?.id).to(equal(docStruct.uuidString))
                    }
                }

                context("with non mergeable conflict") {
                    let ancestor = "1\n2\n3\n"
                    let newRemote = "0\n2\n3\n"
                    let newLocal = "2\n2\n3\n"

                    beforeEach {
                        docStruct = self.helper.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("updates the remote document with the local version") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            self.sut.saveDocumentStructOnAPI(docStruct) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() }.to(beTrue())

                                // When this is failing randomly, rerun. This is because of the way
                                // `BeamNote` saves document looking for links
                                expect(APIRequest.callsCount - networkCalls).to(equal(3))
                                done()
                            }
                        }

                        let newDocStruct = self.sut.loadDocumentById(id: docStruct.id)
                        expect(newDocStruct?.data.asString).to(equal(newLocal))

                        // The API returns an old version if asked too quickly, a bit of latency helps... :(
                        var succeeded = false
                        for _ in 0...3 {
                            let remoteStruct = self.helper.fetchOnAPI(docStruct)
                            expect(remoteStruct?.id).to(equal(docStruct.uuidString))
                            if remoteStruct?.data == newLocal {
                                succeeded = true
                                break
                            }
                            usleep(50)
                        }

                        expect(succeeded).to(beTrue())
                    }
                }

                context("with mergeable conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4\n"
                    let newLocal = "0\n1\n2\n3"
                    let merged = "0\n1\n2\n3\n4\n"

                    beforeEach {
                        docStruct = self.helper.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("updates the remote document") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            self.sut.saveDocumentStructOnAPI(docStruct) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() }.to(beTrue())

                                // We expect 2 calls, but sometimes 5. This is because of the way
                                // `BeamNote` saves document looking for links
                                expect([2, 5]).to(contain(APIRequest.callsCount - networkCalls))
                                done()
                            }
                        }

                        let newDocStruct = self.sut.loadDocumentById(id: docStruct.id)
                        expect(newDocStruct?.data.asString).to(equal(merged))

                        // The API returns an old version if asked too quickly, a bit of latency helps... :(
                        var succeeded = false
                        for _ in 0...5 {
                            let remoteStruct = self.helper.fetchOnAPI(docStruct)
                            expect(remoteStruct?.id).to(equal(docStruct.uuidString))
                            if remoteStruct?.data == merged {
                                succeeded = true
                                break
                            }
                            usleep(50)
                        }

                        expect(succeeded).to(beTrue())
                    }
                }
            }
        }
    }
}
