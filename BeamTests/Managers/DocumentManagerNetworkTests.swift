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
        let fixedDate = "2021-03-19T12:21:03Z"

        beforeEach {
            Configuration.reset()
            BeamDate.freeze(fixedDate)

            coreDataManager = CoreDataManager()
            // Setup CoreData
            coreDataManager.setupWithoutMigration()
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
            BeamDate.reset()
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
                docStruct = self.createStruct("Doc 1", "995d94e1-e0df-4eca-93e6-8778984bcd18", helper)
                helper.saveRemotely(docStruct)
            }

            afterEach {
                helper.deleteDocumentStruct(docStruct)
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

            context("when remote has the same checksum") {
                beforeEach {
                    docStruct = self.createStruct("Doc 1", "995d94e1-e0df-4eca-93e6-8778984bcd18", helper)
                    helper.saveRemotely(docStruct)
                    networkCalls = APIRequest.callsCount
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
                    /*
                     Generated those with the app, and looked at the website https://app.beamapp.co
                     for the exact content of `data`.

                     Without conflicts means the API side of the data was changed by another device, and the local data wasn't
                     modified since its network save. The state should be:

                     localDocument:
                     localDocStruct.data = ancestor
                     localDocStruct.previousData = ancestor
                     localDocStruct.previousChecksum = ancestor.SHA256

                     remoteDocument:
                     remoteDocument.data = newRemote
                     remoteDocument.dataChecksum = newRemote.SHA256
                     remoteDocument.previousChecksum = whatever (the remote object could have been updated a few times)
                     */

                    // 1\n2\n3
                    let ancestor = "{\n \"id\" : \"6E38CEAB-8736-4D29-9A5C-C977AB348D99\",\n \"textStats\" : {\n \"wordsCount\" : 3\n },\n \"visitedSearchResults\" : [\n\n ],\n \"sources\" : {\n \"sources\" : [\n\n ]\n },\n \"type\" : {\n \"type\" : \"note\"\n },\n \"title\" : \"foobar\",\n \"searchQueries\" : [\n\n ],\n \"open\" : true,\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"\"\n }\n ]\n },\n \"readOnly\" : false,\n \"children\" : [\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"13100D1A-DB4E-4B6B-9F19-21E42771ED89\",\n \"creationDate\" : 652264320.13673794,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"1\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"E1F40F11-7B40-42EA-B684-FF7693A7BD61\",\n \"creationDate\" : 652264320.85678303,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"2\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"C2B93826-5141-4F25-8355-009DAB90C99E\",\n \"creationDate\" : 652264321.33729601,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"3\"\n }\n ]\n }\n }\n ],\n \"score\" : 0.20000000298023224,\n \"creationDate\" : 652263910.29682195\n}"
                    // 1\n2\3\n4
                    let newRemote = "{\n \"id\" : \"6E38CEAB-8736-4D29-9A5C-C977AB348D99\",\n \"textStats\" : {\n \"wordsCount\" : 4\n },\n \"visitedSearchResults\" : [\n\n ],\n \"sources\" : {\n \"sources\" : [\n\n ]\n },\n \"type\" : {\n \"type\" : \"note\"\n },\n \"title\" : \"foobar\",\n \"searchQueries\" : [\n\n ],\n \"open\" : true,\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"\"\n }\n ]\n },\n \"readOnly\" : false,\n \"children\" : [\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"13100D1A-DB4E-4B6B-9F19-21E42771ED89\",\n \"creationDate\" : 652264320.13673794,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"1\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"E1F40F11-7B40-42EA-B684-FF7693A7BD61\",\n \"creationDate\" : 652264320.85678303,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"2\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"C2B93826-5141-4F25-8355-009DAB90C99E\",\n \"creationDate\" : 652264321.33729601,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"3\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"3A79B086-AF4A-42C5-A17B-4F5487FD6737\",\n \"creationDate\" : 652264356.52260804,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"4\"\n }\n ]\n }\n }\n ],\n \"score\" : 0.20000000298023224,\n \"creationDate\" : 652263910.29682195\n}"

                    beforeEach {
                        docStruct = try? helper.createLocalAndRemoteVersionsWithData(ancestor,
                                                                                     newRemote: newRemote,
                                                                                     "6E38CEAB-8736-4D29-9A5C-C977AB348D99",
                                                                                     "Document Title")

                        networkCalls = APIRequest.callsCount
                    }

                    afterEach {
                        helper.deleteDocumentStruct(docStruct)
                    }

                    context("with Foundation") {
                        it("refreshes the local document") {
                            // 1st: making sure the local data is `ancestor`
                            guard let savedDocStruct = sut.loadById(id: docStruct.id, includeDeleted: false) else {
                                fail("No coredata instance")
                                return
                            }

                            expect(savedDocStruct.data) == ancestor.asData

                            guard let cdDocStruct = try? sut.fetchWithId(docStruct.id, includeDeleted: false) else {
                                fail("No coredata instance")
                                return
                            }
                            //

                            expect(cdDocStruct.data) == ancestor.asData
                            sut.context.refresh(cdDocStruct, mergeChanges: false)
                            expect(cdDocStruct.data) == ancestor.asData

                            waitUntil(timeout: .seconds(10)) { done in
                                try? sut.refresh(docStruct) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() } == true
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 2

                            // 2nd: making sure the local data is `newRemote`
                            guard let savedDocStruct = sut.loadById(id: docStruct.id, includeDeleted: false) else {
                                fail("No coredata instance")
                                return
                            }

                            expect(savedDocStruct.data) == newRemote.asData

                            guard let cdDocStruct = try? sut.fetchWithId(docStruct.id, includeDeleted: false) else {
                                fail("No coredata instance")
                                return
                            }

                            expect(cdDocStruct.data) == newRemote.asData
                            sut.context.refresh(cdDocStruct, mergeChanges: false)
                            expect(cdDocStruct.data) == newRemote.asData
                        }
                    }
                }

                context("with conflict") {
                    /*
                     Generated those with the app, and looked at the website https://app.beamapp.co
                     for the exact content of `data`.

                     With conflicts means the API side of the data was changer by another device, and the local data was
                     modified since its network save. The state should be:

                     localDocument:
                     localDocStruct.data = newLocal
                     localDocStruct.previousData = ancestor
                     localDocStruct.previousChecksum = ancestor.SHA256

                     remoteDocument:
                     remoteDocument.data = newRemote
                     remoteDocument.dataChecksum = newRemote.SHA256
                     remoteDocument.previousChecksum = whatever (the remote object could have been updated a few times)
                     */

                    // 1\n2\n3
                    let ancestor = "{\n \"id\" : \"6E38CEAB-8736-4D29-9A5C-C977AB348D99\",\n \"textStats\" : {\n \"wordsCount\" : 3\n },\n \"visitedSearchResults\" : [\n\n ],\n \"sources\" : {\n \"sources\" : [\n\n ]\n },\n \"type\" : {\n \"type\" : \"note\"\n },\n \"title\" : \"foobar\",\n \"searchQueries\" : [\n\n ],\n \"open\" : true,\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"\"\n }\n ]\n },\n \"readOnly\" : false,\n \"children\" : [\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"13100D1A-DB4E-4B6B-9F19-21E42771ED89\",\n \"creationDate\" : 652264320.13673794,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"1\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"E1F40F11-7B40-42EA-B684-FF7693A7BD61\",\n \"creationDate\" : 652264320.85678303,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"2\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"C2B93826-5141-4F25-8355-009DAB90C99E\",\n \"creationDate\" : 652264321.33729601,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"3\"\n }\n ]\n }\n }\n ],\n \"score\" : 0.20000000298023224,\n \"creationDate\" : 652263910.29682195\n}"
                    // 1\n2\3\n4
                    let newRemote = "{\n \"id\" : \"6E38CEAB-8736-4D29-9A5C-C977AB348D99\",\n \"textStats\" : {\n \"wordsCount\" : 4\n },\n \"visitedSearchResults\" : [\n\n ],\n \"sources\" : {\n \"sources\" : [\n\n ]\n },\n \"type\" : {\n \"type\" : \"note\"\n },\n \"title\" : \"foobar\",\n \"searchQueries\" : [\n\n ],\n \"open\" : true,\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"\"\n }\n ]\n },\n \"readOnly\" : false,\n \"children\" : [\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"13100D1A-DB4E-4B6B-9F19-21E42771ED89\",\n \"creationDate\" : 652264320.13673794,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"1\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"E1F40F11-7B40-42EA-B684-FF7693A7BD61\",\n \"creationDate\" : 652264320.85678303,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"2\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"C2B93826-5141-4F25-8355-009DAB90C99E\",\n \"creationDate\" : 652264321.33729601,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"3\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"3A79B086-AF4A-42C5-A17B-4F5487FD6737\",\n \"creationDate\" : 652264356.52260804,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"4\"\n }\n ]\n }\n }\n ],\n \"score\" : 0.20000000298023224,\n \"creationDate\" : 652263910.29682195\n}"
                    // 0\n1\n2\n3
                    let newLocal = "{\n \"id\" : \"6E38CEAB-8736-4D29-9A5C-C977AB348D99\",\n \"textStats\" : {\n \"wordsCount\" : 4\n },\n \"visitedSearchResults\" : [\n\n ],\n \"sources\" : {\n \"sources\" : [\n\n ]\n },\n \"type\" : {\n \"type\" : \"note\"\n },\n \"title\" : \"foobar\",\n \"searchQueries\" : [\n\n ],\n \"open\" : true,\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"\"\n }\n ]\n },\n \"readOnly\" : false,\n \"children\" : [\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"13100D1A-DB4E-4B6B-9F19-21E42771ED89\",\n \"creationDate\" : 652264320.13673794,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"0\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"33D246F8-706B-485B-95A5-E7C07C22C804\",\n \"creationDate\" : 652264380.09525394,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"1\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"E1F40F11-7B40-42EA-B684-FF7693A7BD61\",\n \"creationDate\" : 652264320.85678303,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"2\"\n }\n ]\n }\n },\n {\n \"readOnly\" : false,\n \"score\" : 0,\n \"id\" : \"C2B93826-5141-4F25-8355-009DAB90C99E\",\n \"creationDate\" : 652264321.33729601,\n \"open\" : true,\n \"textStats\" : {\n \"wordsCount\" : 1\n },\n \"text\" : {\n \"ranges\" : [\n {\n \"string\" : \"3\"\n }\n ]\n }\n }\n ],\n \"score\" : 0.20000000298023224,\n \"creationDate\" : 652263910.29682195\n}"

                    let merged = "0\n1\n2\n3\n4"

                    beforeEach {
                        docStruct = try! helper.createLocalAndRemoteVersionsWithData(ancestor,
                                                                                     newLocal: newLocal,
                                                                                     newRemote: newRemote,
                                                                                     "6E38CEAB-8736-4D29-9A5C-C977AB348D99",
                                                                                     "Document Title")

                        expect(docStruct.data) == newLocal.asData

                        let remoteStruct = helper.fetchOnAPI(docStruct)
                        expect(remoteStruct?.data) == newRemote.asData

                        let localDocStruct = sut.loadById(id: docStruct.id, includeDeleted: false)!
                        expect(localDocStruct.data) == newLocal.asData
                        expect(localDocStruct.previousSavedObject?.data) == ancestor.asData
                    }

                    afterEach {
                        helper.deleteDocumentStruct(docStruct)
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

                            let newDocStruct = sut.loadById(id: docStruct.id, includeDeleted: false)
                            expect(try? newDocStruct?.textDescription()) == merged
                        }
                    }
                }
            }

            context("when remote beam object doesn't exist") {
                beforeEach {
                    docStruct = self.createStruct("Doc 1", "995d94e1-e0df-4eca-93e6-8778984bcd18", helper)
                    networkCalls = APIRequest.callsCount
                }

                context("with Foundation") {
                    it("doesn't refresh the local document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            try? sut.refresh(docStruct) { result in
                                expect { try result.get() } == false
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        let newDocStruct = sut.loadById(id: docStruct.id, includeDeleted: false)
                        expect(newDocStruct).toNot(beNil())

                        // TODO: should a refresh returning false (no object on the API side) set the local object
                        // as deleted?
                        expect(newDocStruct?.deletedAt).to(beNil())
                    }
                }
            }
        }

        describe(".save()") {
            var docStruct: DocumentStruct!
            beforeEach {
                docStruct = helper.createDocumentStruct(title: "Document Title", id: "995d94e1-e0df-4eca-93e6-8778984bcd18")
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

                        let count = sut.count(filters: [.id(docStruct.id)])
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
                                                        "delete_all_beam_objects",
                                                        "delete_all_beam_objects",
                                                        "update_beam_object"]

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

            describe("saveOnBeamObjectAPI()") {
                var docStruct: DocumentStruct!
                beforeEach {
                    docStruct = helper.createDocumentStruct(title: "Doc 3",
                                                            id: "995d94e1-e0df-4eca-93e6-8778984bcd29")
                    _ = helper.saveLocally(docStruct)
                }

                afterEach {
                    beamObjectHelper.delete(docStruct)
                }

                context("Foundation") {
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

                        let remoteObject: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                        expect(remoteObject) == docStruct
                    }
                }
                context("PromiseKit") {
                    it("saves as beamObject") {
                        let promise: PromiseKit.Promise<DocumentStruct> = sut.saveOnBeamObjectAPI(docStruct)

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.done { receivedDocStruct in
                                expect(receivedDocStruct) == docStruct
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        let remoteObject: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                        expect(remoteObject) == docStruct
                    }
                }
                context("Promises") {
                    it("saves as beamObject") {
                        let promise: Promises.Promise<DocumentStruct> = sut.saveOnBeamObjectAPI(docStruct)

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.then { receivedDocStruct in
                                expect(receivedDocStruct) == docStruct
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        let remoteObject: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                        expect(remoteObject) == docStruct
                    }
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

                context("Foundation") {
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

                        let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                        expect(remoteObject1) == docStruct

                        let remoteObject2: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct2)
                        expect(remoteObject2) == docStruct2
                    }
                }
                context("PromiseKit") {
                    it("saves as beamObjects") {
                        let objects: [DocumentStruct] = [docStruct, docStruct2]
                        let promise: PromiseKit.Promise<[DocumentStruct]> = sut.saveOnBeamObjectsAPI(objects)

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.done { receivedObjects in
                                expect(receivedObjects) == objects
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                        expect(remoteObject1) == docStruct

                        let remoteObject2: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct2)
                        expect(remoteObject2) == docStruct2
                    }
                }
                context("Promises") {
                    it("saves as beamObjects") {
                        let objects: [DocumentStruct] = [docStruct, docStruct2]
                        let promise: Promises.Promise<[DocumentStruct]> = sut.saveOnBeamObjectsAPI(objects)

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.then { receivedObjects in
                                expect(receivedObjects) == objects
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                        expect(remoteObject1) == docStruct

                        let remoteObject2: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct2)
                        expect(remoteObject2) == docStruct2
                    }
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
                    beamObjectHelper.delete(docStruct)
                    beamObjectHelper.delete(docStruct2)
                }

                context("Foundation") {
                    it("saves as beamObjects") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveAllOnBeamObjectApi { result in
                                    expect { try result.get() }.toNot(throwError())

                                    do {
                                        let result = try result.get()
                                        expect(result.0) == 2
                                    } catch {
                                        fail(error.localizedDescription)
                                    }
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                        expect(remoteObject1) == docStruct

                        let remoteObject2: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct2)
                        expect(remoteObject2) == docStruct2
                    }
                }
                context("PromiseKit") {
                    it("saves as beamObjects") {
                        let promise: PromiseKit.Promise<[DocumentStruct]> = sut.saveAllOnBeamObjectApi()
                        
                        waitUntil(timeout: .seconds(10)) { done in
                            promise.done { documents in
                                expect(documents).to(haveCount(2))
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }
                        
                        let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                        expect(remoteObject1) == docStruct
                        
                        let remoteObject2: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct2)
                        expect(remoteObject2) == docStruct2
                    }
                }
                context("Promises") {
                    it("saves as beamObjects") {
                        let promise: Promises.Promise<[DocumentStruct]> = sut.saveAllOnBeamObjectApi()
                        
                        waitUntil(timeout: .seconds(10)) { done in
                            promise.then { documents in
                                expect(documents).to(haveCount(2))
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }
                        
                        let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                        expect(remoteObject1) == docStruct
                        
                        let remoteObject2: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct2)
                        expect(remoteObject2) == docStruct2
                    }
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

                    expect(1) == sut.count(filters: [.id(docStruct.id)])
                    expect(1) == sut.count(filters: [.id(docStruct2.id)])
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

                            expect(1) == sut.count(filters: [.id(docStruct.id)])
                            expect(1) == sut.count(filters: [.id(docStruct2.id)])

                            expect(try? sut.fetchWithId(docStruct.id, includeDeleted: false)?.title) == docStruct.title
                            expect(try? sut.fetchWithId(docStruct2.id, includeDeleted: false)?.title) == docStruct2.title
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

                            expect(sut.count(filters: [.id(docStruct.id)])) == 1
                            expect(sut.count(filters: [.id(docStruct2.id)])) == 0

                            expect(try? sut.fetchWithId(docStruct.id, includeDeleted: false)?.title) == docStruct.title

                            expect(try? sut.fetchWithId(docStruct2.id, includeDeleted: true)?.title) == docStruct2.title

                            let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                            expect(remoteObject1).to(beNil())

                            let remoteObject2: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct2)
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

                            expect(1) == sut.count(filters: [.id(docStruct.id)])
                            expect(1) == sut.count(filters: [.id(docStruct2.id)])

                            expect(try? sut.fetchWithId(docStruct.id, includeDeleted: false)?.title) == docStruct.title
                            expect(try? sut.fetchWithId(docStruct2.id, includeDeleted: false)?.title) == docStruct2.title
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

                            expect(sut.count(filters: [.id(docStruct.id)])) == 1
                            expect(sut.count(filters: [.id(docStruct2.id)])) == 1

                            docStruct2.title = "\(newTitle1) (2)"

                            expect(try? sut.fetchWithId(docStruct.id, includeDeleted: false)?.title) == docStruct.title
                            expect(try? sut.fetchWithId(docStruct2.id, includeDeleted: false)?.title) == docStruct2.title

                            let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                            expect(remoteObject1).to(beNil())

                            let remoteObject2: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct2)
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

                            expect(sut.count(filters: [.id(docStruct.id)])) == 0
                            expect(sut.count(filters: [.id(docStruct3.id)])) == 1

                            expect(try? sut.fetchWithId(docStruct.id, includeDeleted: false)).to(beNil())
                            expect(try? sut.fetchWithId(docStruct3.id, includeDeleted: false)?.title) == docStruct.title

                            let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                            expect(remoteObject1).to(beNil())

                            let remoteObject3: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct3)
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

                            expect(sut.count(filters: [.id(docStruct.id)])) == 1
                            expect(sut.count(filters: [.id(docStruct3.id)])) == 0

                            let localDocument = try? sut.fetchWithId(docStruct.id, includeDeleted: false)
                            expect(localDocument?.title) == docStruct.title
                            expect(localDocument?.deleted_at).to(beNil())

                            let remoteObject1: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct)
                            expect(remoteObject1).to(beNil())

                            let remoteObject3: DocumentStruct? = try? beamObjectHelper.fetchOnAPI(docStruct3)
                            expect(remoteObject3?.deletedAt).toNot(beNil())
                        }
                    }
                }
            }
        }
    }

    private func createStruct(_ title: String = "Document Title", _ id: String?, _ helper: DocumentManagerTestsHelper) -> DocumentStruct {
        var docStruct = helper.createDocumentStruct(title: title, id: id)
        docStruct = helper.saveLocally(docStruct)

        return docStruct
    }
}
