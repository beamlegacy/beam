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
@testable import BeamCore

// swiftlint:disable:next type_body_length
class DocumentManagerNetworkTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        // MARK: Properties
        var coreDataManager: CoreDataManager!
        var sut: DocumentManager!
        var helper: DocumentManagerTestsHelper!
        let beamHelper = BeamTestsHelper()

        beforeEach {
            Configuration.reset()

            coreDataManager = CoreDataManager()
            // Setup CoreData
            coreDataManager.setup()
            CoreDataManager.shared = coreDataManager
            sut = DocumentManager(coreDataManager: coreDataManager)
            helper = DocumentManagerTestsHelper(documentManager: sut,
                                                     coreDataManager: coreDataManager)

            DocumentManager.cancelAllPreviousThrottledAPICall()
            BeamObjectManager.clearNetworkCalls()
            BeamTestsHelper.logout()

            beamHelper.beginNetworkRecording()

            // Try to avoid issues with BeamTextTests creating documents when parsing links
            BeamNote.clearCancellables()

            BeamTestsHelper.login()

            helper.deleteAllDatabases()
            helper.deleteAllDocuments()

            Persistence.Sync.cleanUp()

            helper.createDefaultDatabase("00000000-e0df-4eca-93e6-8778984bcd18")

            try? EncryptionManager.shared.replacePrivateKey(Configuration.testPrivateKey)
        }

        afterEach {
            beamHelper.endNetworkRecording()

            BeamObjectManager.clearNetworkCalls()
        }

        describe(".saveAllOnAPI()") {
            var docStruct: DocumentStruct!
            beforeEach {
                docStruct = self.createStruct("Doc 1", "995d94e1-e0df-4eca-93e6-8778984bcd18", helper)
            }

            afterEach {
                helper.deleteDocumentStruct(docStruct)
            }

            context("with Foundation") {
                it("uploads existing documents") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.saveAllOnAPI { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == true
                            done()
                        }
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1

                    let remoteStruct = helper.fetchOnAPI(docStruct)
                    expect(remoteStruct) == docStruct
                }
            }

            context("with PromiseKit") {
                it("uploads existing documents") {
                    let networkCalls = APIRequest.callsCount
                    let promise: PromiseKit.Promise<Bool> = sut.saveAllOnAPI()

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.done { success in
                            expect(success) == true
                            done()
                        }.catch { error in
                            fail("Should not happen: \(error)")
                        }
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1

                    let remoteStruct = helper.fetchOnAPI(docStruct)
                    expect(remoteStruct?.id) == docStruct.id
                    expect(remoteStruct?.data) == docStruct.data
                }
            }

            context("with Promises") {
                it("uploads existing documents") {
                    let networkCalls = APIRequest.callsCount
                    let promise: Promises.Promise<Bool> = sut.saveAllOnAPI()

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.then { success in
                            expect(success) == true
                            done()
                        }.catch { error in
                            fail("Should not happen: \(error)")
                            done()
                        }
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1

                    let remoteStruct = helper.fetchOnAPI(docStruct)
                    expect(remoteStruct?.id) == docStruct.id
                    expect(remoteStruct?.data) == docStruct.data
                }
            }
        }

        describe(".fetchAllOnApi()") {
            var docStruct: DocumentStruct!
            beforeEach {
                BeamDate.freeze("2021-03-19T12:21:03Z")
                docStruct = self.createStruct("Doc 1", "995d94e1-e0df-4eca-93e6-8778984bcd18", helper)
                helper.saveRemotely(docStruct)
            }

            afterEach {
                helper.deleteDocumentStruct(docStruct)
                BeamDate.reset()
            }

            context("with Foundation") {
                it("refreshes the local document") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            try sut.fetchAllOnApi { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() } == true
                                done()
                            }
                        } catch {
                            fail("Should not happen")
                            done()
                        }
                    }
                    expect(APIRequest.callsCount - networkCalls) == 1
                }
            }
        }

        describe(".refresh()") {
            var docStruct: DocumentStruct!
            var networkCalls: Int!

            afterEach {
                // Not to leave any on the server
                helper.deleteDocumentStruct(docStruct)
            }

            context("when remote has the same updatedAt") {
                beforeEach {
                    BeamDate.freeze("2021-03-19T12:21:03Z")
                    docStruct = self.createStruct("Doc 1", "995d94e1-e0df-4eca-93e6-8778984bcd18", helper)
                    helper.saveRemotely(docStruct)
                    networkCalls = APIRequest.callsCount
                }

                afterEach {
                    BeamDate.reset()
                }

                afterEach {
                    helper.deleteDocumentStruct(docStruct)
                }

                context("with Foundation") {
                    it("doesn't refresh the local document") {
                        expect(AuthenticationManager.shared.isAuthenticated) == true
                        expect(Configuration.networkEnabled) == true

                        waitUntil(timeout: .seconds(10)) { done in
                            try? sut.refresh(docStruct) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() } == false
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1
                    }
                }
            }

            context("when remote has a more recent updatedAt") {
                context("without conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4"

                    beforeEach {
                        BeamDate.freeze("2021-03-19T12:21:03Z")
                        docStruct = try? helper.createLocalAndRemoteVersions(ancestor,
                                                                             newRemote: newRemote,
                                                                             "995d94e1-e0df-4eca-93e6-8778984bcd18")
                        networkCalls = APIRequest.callsCount
                    }

                    afterEach {
                        helper.deleteDocumentStruct(docStruct)
                        BeamDate.reset()
                    }

                    context("with Foundation") {
                        it("refreshes the local document") {
                            waitUntil(timeout: .seconds(10)) { done in
                                try? sut.refresh(docStruct) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() } == true
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 2

                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data) == newRemote.asData
                        }
                    }
                }

                context("with conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4\n"
                    let newLocal = "0\n1\n2\n3"
                    let merged = "0\n1\n2\n3\n4\n"

                    beforeEach {
                        BeamDate.freeze("2021-03-19T12:21:03Z")

                        docStruct = try! helper.createLocalAndRemoteVersions(ancestor,
                                                                             newLocal: newLocal,
                                                                             newRemote: newRemote,
                                                                             "995d94e1-e0df-4eca-93e6-8778984bcd18")
                    }

                    afterEach {
                        helper.deleteDocumentStruct(docStruct)
                        BeamDate.reset()
                    }

                    context("with Foundation") {
                        it("refreshes the local document") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                try? sut.refresh(docStruct) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() } == true
                                    done()
                                }
                            }

                            expect([2, 5]).to(contain(APIRequest.callsCount - networkCalls))

                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data.asString) == merged
                        }
                    }
                }
            }

            context("when remote document doesn't exist") {
                beforeEach {
                    docStruct = self.createStruct("Doc 1", "995d94e1-e0df-4eca-93e6-8778984bcd18", helper)
                    networkCalls = APIRequest.callsCount
                }

                context("with Foundation") {
                    it("doesn't refresh the local document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            try? sut.refresh(docStruct) { result in
                                expect { try result.get() }.to(throwError { error in
                                    expect(error).to(matchError(APIRequestError.notFound))
                                })
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        let newDocStruct = sut.loadById(id: docStruct.id)
                        expect(newDocStruct).toNot(beNil())
                        expect(newDocStruct?.deletedAt).toNot(beNil())
                    }
                }
            }
        }

        describe(".save()") {
            var docStruct: DocumentStruct!
            beforeEach {
                docStruct = helper.createDocumentStruct(id: "995d94e1-e0df-4eca-93e6-8778984bcd18")
            }
            afterEach {
                helper.deleteDocumentStruct(docStruct)
            }

            context("with network") {
                context("without conflict") {
                    it("saves the document locally") {
                        waitUntil(timeout: .seconds(10)) { done in
                            docStruct.version += 1
                            sut.save(docStruct,
                                     true,
                                     { _ in done() })
                        }

                        let count = Document.countWithPredicate(coreDataManager.mainContext,
                                                                NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                        expect(count) == 1
                    }

                    context("with Foundation") {
                        context("with an existing local document, but non existing on the API") {
                            beforeEach {
                                docStruct = helper.saveLocally(docStruct)
                            }

                            it("saves the document on the API") {
                                waitUntil(timeout: .seconds(10)) { done in
                                    sut.saveDocumentStructOnAPI(docStruct) { result in
                                        expect { try result.get() }.toNot(throwError())
                                        expect { try result.get() } == true
                                        done()
                                    }
                                }

                                let remoteStruct = helper.fetchOnAPI(docStruct)
                                expect(remoteStruct?.id) == docStruct.id
                                expect(remoteStruct?.isPublic) == false
                            }

                            xit("cancels previous unfinished saves") {
                                beamHelper.disableNetworkRecording()
                                helper.deleteAllDatabases()
                                docStruct = helper.createDocumentStruct()
                                docStruct = helper.saveLocally(docStruct)

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

                        context("with an existing local deleted document, but non existing on the API") {
                            beforeEach {
                                docStruct.deletedAt = BeamDate.now
                                docStruct = helper.saveLocally(docStruct)
                            }

                            it("saves the document on the API") {
                                let previousNetworkCall = APIRequest.callsCount

                                waitUntil(timeout: .seconds(10)) { done in
                                    sut.saveDocumentStructOnAPI(docStruct) { result in
                                        expect { try result.get() }.toNot(throwError())
                                        expect { try result.get() } == true
                                        done()
                                    }
                                }

                                expect(APIRequest.callsCount - previousNetworkCall) == 1
                            }
                        }
                    }

                    context("with PromiseKit") {
                        beforeEach {
                            docStruct = helper.saveLocally(docStruct)
                        }

                        it("saves the document on the API") {
                            let promise: PromiseKit.Promise<Bool> = sut.saveOnApi(docStruct)

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { success in
                                    expect(success) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)"); done() }
                            }

                            let remoteStruct = helper.fetchOnAPI(docStruct)
                            expect(remoteStruct) == docStruct
                        }

                        xit("cancels previous unfinished saves") {
                            beamHelper.disableNetworkRecording()
                            helper.deleteAllDatabases()
                            docStruct = helper.createDocumentStruct()
                            docStruct = helper.saveLocally(docStruct)

                            let previousNetworkCall = APIRequest.callsCount
                            let times = 10
                            let title = docStruct.title
                            var newTitle = title

                            for index in 0..<times {
                                newTitle = "\(title) - \(index)"
                                docStruct.title = newTitle
                                docStruct.version += 1
                                let promise: PromiseKit.Promise<Bool> = sut.saveOnApi(docStruct)
                                promise.done {
                                    fail("Should not be called: \($0) for \(docStruct.titleAndId)")
                                }.catch { error in
                                    expect(error).to(matchError(DocumentManagerError.operationCancelled))
                                }
                            }

                            newTitle = "\(title) - last"
                            waitUntil(timeout: .seconds(10)) { done in
                                docStruct.title = newTitle
                                docStruct.version += 1
                                let promise: PromiseKit.Promise<Bool> = sut.saveOnApi(docStruct)
                                promise.done { success in
                                    expect(success) == true
                                    done()
                                }.catch {
                                    fail("Should not be called: \($0) for \(docStruct.titleAndId)")
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - previousNetworkCall) == 1

                            let remoteStruct = helper.fetchOnAPI(docStruct)
                            expect(remoteStruct?.title) == newTitle
                        }
                    }

                    context("with Promises") {
                        beforeEach {
                            docStruct = helper.saveLocally(docStruct)
                        }

                        it("saves the document on the API") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<Bool> = sut.saveOnApi(docStruct)

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { success in
                                    expect(success) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)"); done() }
                            }

                            let expectedNetworkCalls = ["sign_in",
                                                        "delete_all_databases",
                                                        "delete_all_documents",
                                                        "update_document"]

                            expect(APIRequest.callsCount - networkCalls) == 1
                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            let remoteStruct = helper.fetchOnAPI(docStruct)
                            expect(remoteStruct) == docStruct
                        }

                        xit("cancels previous unfinished saves") {
                            beamHelper.disableNetworkRecording()
                            helper.deleteAllDatabases()
                            docStruct = helper.createDocumentStruct()
                            docStruct = helper.saveLocally(docStruct)

                            let previousNetworkCall = APIRequest.callsCount
                            let times = 10
                            let title = docStruct.title
                            var newTitle = title

                            for index in 0..<times {
                                newTitle = "\(title) - \(index)"
                                docStruct.title = newTitle
                                docStruct.version += 1
                                let promise: Promises.Promise<Bool> = sut.saveOnApi(docStruct)
                                promise.then {
                                    fail("Should not be called: \($0) for \(docStruct.titleAndId)")
                                }.catch { error in
                                    expect(error).to(matchError(DocumentManagerError.operationCancelled))
                                }
                            }

                            newTitle = "\(title) - last"
                            waitUntil(timeout: .seconds(10)) { done in
                                docStruct.title = newTitle
                                docStruct.version += 1
                                let promise: Promises.Promise<Bool> = sut.saveOnApi(docStruct)
                                promise.then { success in
                                    expect(success) == true
                                    done()
                                }.catch { fail("Should not be called: \($0) for \(docStruct.titleAndId)"); done() }
                            }

                            expect(APIRequest.callsCount - previousNetworkCall) == 1

                            let remoteStruct = helper.fetchOnAPI(docStruct)
                            expect(remoteStruct?.title) == newTitle
                        }
                    }
                }
            }
        }

        describe("BeamObject API") {
            let beamObjectHelper: BeamObjectTestsHelper = BeamObjectTestsHelper()

            beforeEach {
                BeamDate.freeze("2021-03-19T12:21:03Z")
            }

            afterEach {
                BeamDate.reset()
            }

            describe("saveOnBeamObjectAPI()") {
                var docStruct: DocumentStruct!
                beforeEach {
                    docStruct = helper.createDocumentStruct(title: "Doc 3",
                                                            id: "995d94e1-e0df-4eca-93e6-8778984bcd29")
                    _ = helper.saveLocally(docStruct)
                }

                afterEach {
                    beamObjectHelper.delete(docStruct.id)
                }

                it("saves as beamObject") {
                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            try sut.saveOnBeamObjectAPI(docStruct) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() } == docStruct
                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }

                    let remoteObject: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct.beamObjectId)
                    expect(remoteObject) == docStruct
                }
            }

            describe("saveOnBeamObjectsAPI()") {
                var docStruct: DocumentStruct!
                var docStruct2: DocumentStruct!
                beforeEach {
                    docStruct = helper.createDocumentStruct(title: "Doc 1", id: "995d94e1-e0df-4eca-93e6-8778984bcd29")
                    _ = helper.saveLocally(docStruct)

                    docStruct2 = helper.createDocumentStruct(title: "Doc 2", id: "995d94e1-e0df-4eca-93e6-8778984bcd39")
                    _ = helper.saveLocally(docStruct2)
                }

                afterEach {
                    helper.deleteDocumentStruct(docStruct)
                    helper.deleteDocumentStruct(docStruct2)
                }

                it("saves as beamObjects") {
                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            let objects: [DocumentStruct] = [docStruct, docStruct2]
                            _ = try sut.saveOnBeamObjectsAPI(objects) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() } == objects
                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }

                    let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct.beamObjectId)
                    expect(remoteObject1) == docStruct

                    let remoteObject2: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct2.beamObjectId)
                    expect(remoteObject2) == docStruct2
                }
            }

            describe("saveAllOnBeamObjectApi()") {
                var docStruct: DocumentStruct!
                var docStruct2: DocumentStruct!

                beforeEach {
                    docStruct = helper.createDocumentStruct(title: "Doc 1", id: "995d94e1-e0df-4eca-93e6-8778984bcd29")
                    _ = helper.saveLocally(docStruct)

                    docStruct2 = helper.createDocumentStruct(title: "Doc 2", id: "995d94e1-e0df-4eca-93e6-8778984bcd39")
                    _ = helper.saveLocally(docStruct2)
                }

                afterEach {
                    beamObjectHelper.delete(docStruct.id)
                    beamObjectHelper.delete(docStruct2.id)
                }

                it("saves as beamObjects") {
                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.saveAllOnBeamObjectApi { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() } == true

                                do {
                                    _ = try result.get()
                                } catch {
                                    fail(error.localizedDescription)
                                }
                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }

                    let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct.beamObjectId)
                    expect(remoteObject1) == docStruct

                    let remoteObject2: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct2.beamObjectId)
                    expect(remoteObject2) == docStruct2
                }
            }

            describe("receivedObjects()") {
                var docStruct: DocumentStruct!
                var docStruct2: DocumentStruct!
                let newTitle1 = "Doc 3"
                let newTitle2 = "Doc 4"

                beforeEach {
                    docStruct = helper.createDocumentStruct(title: "Doc 1", id: "995d94e1-e0df-4eca-93e6-8778984bcd29")
                    docStruct2 = helper.createDocumentStruct(title: "Doc 2", id: "995d94e1-e0df-4eca-93e6-8778984bcd39")
                }

                afterEach {
                    helper.deleteDocumentStruct(docStruct)
                    helper.deleteDocumentStruct(docStruct2)
                }

                it("saves to local objects") {
                    let objects: [DocumentStruct] = [docStruct, docStruct2]

                    try sut.receivedObjects(objects)

                    expect(1) == Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                             NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                    expect(1) == Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                             NSPredicate(format: "id = %@", docStruct2.id as CVarArg))
                }

                context("without any locally saved documents") {
                    beforeEach {
                        helper.deleteDocumentStruct(docStruct)
                        helper.deleteDocumentStruct(docStruct2)
                    }

                    context("with 2 documents with different titles") {
                        it("saves to local objects") {
                            let networkCalls = APIRequest.callsCount

                            try sut.receivedObjects([docStruct, docStruct2])

                            expect(APIRequest.callsCount - networkCalls) == 0

                            expect(1) == Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                                     NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                            expect(1) == Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                                     NSPredicate(format: "id = %@", docStruct2.id as CVarArg))

                            expect(try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct.id)?.title) == docStruct.title
                            expect(try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct2.id)?.title) == docStruct2.title
                        }
                    }

                    context("with 2 documents with same titles") {
                        beforeEach {
                            docStruct = helper.createDocumentStruct(title: "Doc 1", id: "995d94e1-e0df-4eca-93e6-8778984bcd29")
                            docStruct2 = helper.createDocumentStruct(title: "Doc 1", id: "995d94e1-e0df-4eca-93e6-8778984bcd39")
                        }

                        it("saves the first locally, delete the 2nd, and save it remotely") {
                            let networkCalls = APIRequest.callsCount

                            try sut.receivedObjects([docStruct, docStruct2])

                            expect(APIRequest.callsCount - networkCalls) == 1

                            let expectedNetworkCalls = ["update_beam_objects"]

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            expect(Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                               NSPredicate(format: "id = %@", docStruct.id as CVarArg))) == 1
                            expect(Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                               NSPredicate(format: "id = %@", docStruct2.id as CVarArg))) == 0

                            expect(try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct.id)?.title) == docStruct.title

                            expect(try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct2.id)?.title) == docStruct2.title

                            let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct.beamObjectId)
                            expect(remoteObject1).to(beNil())

                            let remoteObject2: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct2.beamObjectId)
                            expect(remoteObject2?.deletedAt).toNot(beNil())
                        }
                    }
                }

                context("with locally saved documents") {
                    beforeEach {
                        docStruct = helper.createDocumentStruct(title: "Doc 1", id: "995d94e1-e0df-4eca-93e6-8778984bcd29")
                        docStruct2 = helper.createDocumentStruct(title: "Doc 2", id: "995d94e1-e0df-4eca-93e6-8778984bcd39")

                        docStruct = helper.fillDocumentStructWithStaticText(docStruct)
                        docStruct2 = helper.fillDocumentStructWithStaticText(docStruct2)

                        _ = helper.saveLocally(docStruct)
                        _ = helper.saveLocally(docStruct2)
                    }

                    context("with 2 documents with different titles") {
                        beforeEach {
                            docStruct.title = newTitle1
                            docStruct2.title = newTitle2
                        }

                        it("saves to local objects") {
                            let networkCalls = APIRequest.callsCount

                            try sut.receivedObjects([docStruct, docStruct2])

                            expect(APIRequest.callsCount - networkCalls) == 0

                            expect(1) == Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                                     NSPredicate(format: "id = %@", docStruct.id as CVarArg))
                            expect(1) == Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                                     NSPredicate(format: "id = %@", docStruct2.id as CVarArg))

                            expect(try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct.id)?.title) == docStruct.title
                            expect(try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct2.id)?.title) == docStruct2.title
                        }
                    }

                    context("with 2 documents with same titles") {
                        beforeEach {
                            docStruct.title = newTitle1
                            docStruct2.title = newTitle1
                        }

                        it("saves to local objects and save it remotely") {
                            let networkCalls = APIRequest.callsCount

                            try sut.receivedObjects([docStruct, docStruct2])

                            expect(APIRequest.callsCount - networkCalls) == 1

                            let expectedNetworkCalls = ["update_beam_objects"]
                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            expect(Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                               NSPredicate(format: "id = %@", docStruct.id as CVarArg))) == 1
                            expect(Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                               NSPredicate(format: "id = %@", docStruct2.id as CVarArg))) == 1

                            docStruct2.title = "\(newTitle1) (2)"

                            expect(try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct.id)?.title) == docStruct.title
                            expect(try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct2.id)?.title) == docStruct2.title

                            let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct.beamObjectId)
                            expect(remoteObject1).to(beNil())

                            let remoteObject2: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct2.beamObjectId)
                            expect(remoteObject2) == docStruct2
                        }
                    }

                    context("with a 3rd non-empty document not locally saved") {
                        var docStruct3: DocumentStruct!
                        beforeEach {
                            docStruct3 = helper.createDocumentStruct(title: docStruct.title, id: "995d94e1-e0df-4eca-93e6-8778984bcd69")
                            docStruct3 = helper.fillDocumentStructWithStaticText(docStruct3)

                            docStruct = helper.fillDocumentStructWithEmptyText(docStruct)
                            docStruct.version += 1
                            _ = helper.saveLocally(docStruct)
                        }

                        afterEach {
                            helper.deleteDocumentStruct(docStruct3)
                        }

                        it("saves to local objects, and delete the local empty document") {
                            let networkCalls = APIRequest.callsCount
                            try sut.receivedObjects([docStruct3])
                            expect(APIRequest.callsCount - networkCalls) == 0

                            expect(Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                               NSPredicate(format: "id = %@", docStruct.id as CVarArg))) == 0
                            expect(Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                               NSPredicate(format: "id = %@", docStruct3.id as CVarArg))) == 1

                            expect(try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct.id)).to(beNil())
                            expect(try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct3.id)?.title) == docStruct.title

                            let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct.beamObjectId)
                            expect(remoteObject1).to(beNil())

                            let remoteObject3: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct3.beamObjectId)
                            expect(remoteObject3).to(beNil())
                        }
                    }

                    context("with a 3rd empty document not locally saved") {
                        var docStruct3: DocumentStruct!
                        beforeEach {
                            docStruct3 = helper.createDocumentStruct(title: docStruct.title, id: "995d94e1-e0df-4eca-93e6-8778984bcd69")
                        }

                        afterEach {
                            helper.deleteDocumentStruct(docStruct3)
                        }

                        it("doesn't save it locally, and flag it deleted remotely") {
                            expect(docStruct3.isEmpty) == true
                            let networkCalls = APIRequest.callsCount
                            try sut.receivedObjects([docStruct3])
                            expect(APIRequest.callsCount - networkCalls) == 1

                            let expectedNetworkCalls = ["update_beam_objects"]
                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            expect(Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                               NSPredicate(format: "id = %@", docStruct.id as CVarArg))) == 1
                            expect(Document.countWithPredicate(CoreDataManager.shared.mainContext,
                                                               NSPredicate(format: "id = %@", docStruct3.id as CVarArg))) == 0

                            let localDocument = try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct.id)
                            expect(localDocument?.title) == docStruct.title
                            expect(localDocument?.deleted_at).to(beNil())

                            let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct.beamObjectId)
                            expect(remoteObject1).to(beNil())

                            let remoteObject3: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct3.beamObjectId)
                            expect(remoteObject3?.deletedAt).toNot(beNil())
                        }
                    }
                }
            }
        }
    }

    private func createStruct(_ title: String?, _ id: String?, _ helper: DocumentManagerTestsHelper) -> DocumentStruct {
        var docStruct = helper.createDocumentStruct(title: title, id: id)
        docStruct = helper.saveLocally(docStruct)

        return docStruct
    }
}
