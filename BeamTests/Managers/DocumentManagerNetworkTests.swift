// swiftlint:disable file_length

import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import Alamofire

// MARK: -
// MARK: Network tests
@testable import Beam
// swiftlint:disable:next type_body_length
class DocumentManagerNetworkTests: QuickSpec {
    // MARK: Properties
    var sut: DocumentManager!
    lazy var coreDataManager = {
        CoreDataManager()
    }()
    lazy var mainContext = {
        coreDataManager.mainContext
    }()

    // swiftlint:disable:next function_body_length
    override func spec() {
        beforeEach {
            self.login()
        }

        afterEach {
            self.sut.clearNetworkCalls()
        }

        beforeSuite {
            // Setup CoreData
            self.coreDataManager.setup()
            waitUntil { done in
                self.coreDataManager.destroyPersistentStore {
                    self.coreDataManager.setup()
                    done()
                }
            }
            CoreDataManager.shared = self.coreDataManager
            self.sut = DocumentManager(coreDataManager: self.coreDataManager)

            // Try to avoid issues with BeamTextTests creating documents when parsing links
            BeamNote.clearCancellables()
        }

        afterSuite {
            self.logout()
        }

        describe(".refreshDocuments()") {
            var docStruct: DocumentStruct!
            afterEach {
                // Not to leave any on the server
                self.deleteDocumentStruct(docStruct)
            }

            context("when remote has the same updatedAt") {
                beforeEach {
                    BeamDate.freeze()
                    docStruct = self.createDocumentStruct()
                    self.saveLocally(docStruct)
                    self.saveRemotely(docStruct)
                }

                afterEach {
                    BeamDate.reset()
                }

                it("refreshes the local document") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil { done in
                        self.sut.refreshDocuments { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() }.to(beTrue())
                            expect(APIRequest.callsCount - networkCalls).to(equal(1))
                            done()
                        }
                    }
                }
            }

            context("when remote document doesn't exist") {
                beforeEach {
                    docStruct = self.createDocumentStruct()
                    self.saveLocally(docStruct)
                }

                it("flags the local document as deleted") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil { done in
                        self.sut.refreshDocuments { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() }.to(beTrue())
                            expect(APIRequest.callsCount - networkCalls).to(equal(1))
                            done()
                        }
                    }

                    let newDocStruct = self.sut.loadDocumentById(id: docStruct.id)
                    expect(newDocStruct).toNot(beNil())
                    expect(newDocStruct?.deletedAt).to(beCloseTo(BeamDate.now, within: 0.1))

                    let document = Document.fetchWithId(self.mainContext, docStruct.id)
                    expect(document?.deleted_at).toNot(beNil())
                }
            }

            context("when remote has a more recent updatedAt") {
                context("without conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4"
                    beforeEach {
                        docStruct = self.createLocalAndRemoteVersions(ancestor, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("refreshes the local document") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil { done in
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
                        docStruct = self.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("refreshes the local document") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil { done in
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
                    docStruct = self.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                }

                afterEach {
                    BeamDate.reset()
                }

                it("doesn't update the local document, returns error") {
                    let networkCalls = APIRequest.callsCount
                    waitUntil { done in
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
                self.deleteDocumentStruct(docStruct)
            }

            context("when remote has the same updatedAt") {
                beforeEach {
                    BeamDate.freeze()
                    docStruct = self.createDocumentStruct()
                    self.saveLocally(docStruct)
                    self.saveRemotely(docStruct)
                }

                afterEach {
                    BeamDate.reset()
                }

                it("doesn't refresh the local document") {
                    let networkCalls = APIRequest.callsCount

                    expect(AuthenticationManager.shared.isAuthenticated).to(beTrue())
                    expect(Configuration.networkEnabled).to(beTrue())

                    waitUntil { done in
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
                        docStruct = self.createLocalAndRemoteVersions(ancestor, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("refreshes the local document") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil { done in
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
                        docStruct = self.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("refreshes the local document") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil { done in
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
                    docStruct = self.createDocumentStruct()
                    self.saveLocally(docStruct)
                }

                it("doesn't refresh the local document") {
                    waitUntil { done in
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
            var docStruct = createDocumentStruct()
            afterEach {
                // Not to leave any on the server
                self.deleteDocumentStruct(docStruct)
            }

            context("with network") {
                context("without conflict") {
                    it("saves the document locally") {
                        waitUntil { done in
                            self.sut.saveDocument(docStruct) { _ in
                                done()
                            }
                        }

                        let count = Document.countWithPredicate(self.mainContext,
                                                                NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                        expect(count).to(equal(1))
                    }

                    it("saves the document on the API") {
                        self.saveLocally(docStruct)

                        waitUntil { done in
                            self.sut.saveDocumentStructOnAPI(docStruct) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() }.to(beTrue())
                                done()
                            }
                        }

                        expect(self.fetchOnAPI(docStruct)?.id).to(equal(docStruct.uuidString))
                    }
                }

                context("with non mergeable conflict") {
                    let ancestor = "1\n2\n3\n"
                    let newRemote = "0\n2\n3\n"
                    let newLocal = "2\n2\n3\n"

                    beforeEach {
                        docStruct = self.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("updates the remote document with the local version") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil { done in
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
                            let remoteStruct = self.fetchOnAPI(docStruct)
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
                        docStruct = self.createLocalAndRemoteVersions(ancestor, newLocal: newLocal, newRemote: newRemote)
                    }

                    afterEach {
                        BeamDate.reset()
                    }

                    it("updates the remote document") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil { done in
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
                            let remoteStruct = self.fetchOnAPI(docStruct)
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

    private func login() {
        let accountManager = AccountManager()
        let email = "fabien+test@beamapp.co"
        let password = Configuration.testAccountPassword

        guard !AuthenticationManager.shared.isAuthenticated else { return }

        waitUntil { done in
            accountManager.signIn(email, password) { _ in
                done()
            }
        }
    }

    private func logout() {
        guard AuthenticationManager.shared.isAuthenticated else { return }

        AccountManager.logout()
    }

    private func deleteDocumentStruct(_ docStruct: DocumentStruct) {
        waitUntil { done in
            self.sut.deleteDocument(id: docStruct.id) { result in
                expect { try result.get() }.toNot(throwError())
                expect { try result.get() }.to(beTrue())
                done()
            }
        }
    }

    private let faker = Faker(locale: "en-US")
    private func createDocumentStruct(_ document: String? = nil) -> DocumentStruct {
        let document = document ?? "whatever binary data"

        //swiftlint:disable:next force_try
        let jsonData = try! self.defaultEncoder().encode(document)

        let id = UUID()
        let title = faker.zelda.game() + " " + randomString(length: 40)
        let docStruct = DocumentStruct(id: id,
                                       title: title,
                                       createdAt: BeamDate.now,
                                       updatedAt: BeamDate.now,
                                       data: jsonData,
                                       documentType: .note)

        return docStruct
    }

    private func saveLocally(_ docStruct: DocumentStruct) {
        // The call to `saveDocumentStructOnAPI` expect the document to be already saved locally
        waitUntil { done in
            // To force a local save only, while using the standard code
            Configuration.networkEnabled = false
            self.sut.saveDocument(docStruct) { _ in
                Configuration.networkEnabled = true
                done()
            }
        }
    }

    private func saveRemotely(_ docStruct: DocumentStruct) {
        waitUntil { done in
            self.sut.saveDocumentStructOnAPI(docStruct) { _ in
                done()
            }
        }
    }

    private func saveRemotelyOnly(_ docStruct: DocumentStruct) {
        waitUntil { done in
            self.sut.documentRequest.saveDocument(docStruct.asApiType()) { _ in
                done()
            }
        }
    }

    private func fetchOnAPI(_ docStruct: DocumentStruct) -> DocumentAPIType? {
        var documentAPIType: DocumentAPIType?
        waitUntil { done in
            self.sut.documentRequest.fetchDocument(docStruct.uuidString) { result in
                documentAPIType = try? result.get()
                done()
            }
        }

        return documentAPIType
    }

    private func createLocalAndRemoteVersions(_ ancestor: String,
                                              newLocal: String? = nil,
                                              newRemote: String? = nil) -> DocumentStruct {
        BeamDate.travel(-600)
        var docStruct = self.createDocumentStruct()
        docStruct.data = ancestor.asData
        // Save document locally + remotely
        self.saveLocally(docStruct)
        self.saveRemotely(docStruct)

        if let newLocal = newLocal {
            // Force to locally save an older version of the document
            BeamDate.travel(2)
            docStruct.updatedAt = BeamDate.now
            docStruct.data = newLocal.asData
            docStruct.previousData = ancestor.asData
            self.saveLocally(docStruct)
        }

        if let newRemote = newRemote {
            // Generates a new version on the API side only
            BeamDate.travel(2)
            var newDocStruct = docStruct.copy()
            newDocStruct.data = newRemote.asData
            newDocStruct.updatedAt.addTimeInterval(2)
            self.saveRemotelyOnly(newDocStruct)
        }

        return docStruct
    }

    private func defaultDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func defaultEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map { _ in letters.randomElement()! })
    }
}
