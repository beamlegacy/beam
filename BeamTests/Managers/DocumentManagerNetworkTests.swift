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
            Configuration.beamObjectAPIEnabled = false

            coreDataManager = CoreDataManager()
            // Setup CoreData
            coreDataManager.setup()
            CoreDataManager.shared = coreDataManager
            sut = DocumentManager(coreDataManager: coreDataManager)
            helper = DocumentManagerTestsHelper(documentManager: sut,
                                                     coreDataManager: coreDataManager)

            DocumentManager.cancelAllPreviousThrottledAPICall()
            sut.clearNetworkCalls()
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

            sut.clearNetworkCalls()
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
                    Configuration.encryptionEnabled = false

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
                    expect(remoteStruct?.id) == docStruct.uuidString
                    expect(remoteStruct?.data) == docStruct.data.asString
                }

                context("with encryption") {
                    it("uploads existing documents") {
                        Configuration.encryptionEnabled = true

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
                        expect(remoteStruct?.id) == docStruct.uuidString
                        expect(remoteStruct?.data) == docStruct.data.asString
                        expect(remoteStruct?.encryptedData).to(match("encryptionName\":\"AES_GCM"))

                        Configuration.encryptionEnabled = false
                    }
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
                    expect(remoteStruct?.id) == docStruct.uuidString
                    expect(remoteStruct?.data) == docStruct.data.asString
                }

                context("with encryption") {
                    it("uploads existing documents") {
                        Configuration.encryptionEnabled = true

                        let networkCalls = APIRequest.callsCount
                        let promise: PromiseKit.Promise<Bool> = sut.saveAllOnAPI()

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.done { success in
                                expect(success) == true
                                done()
                            }.catch { error in
                                fail("Should not happen: \(error)")
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        let remoteStruct = helper.fetchOnAPI(docStruct)
                        expect(remoteStruct?.id) == docStruct.uuidString
                        expect(remoteStruct?.data) == docStruct.data.asString
                        expect(remoteStruct?.encryptedData).to(match("encryptionName\":\"AES_GCM"))

                        Configuration.encryptionEnabled = false
                    }
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
                    expect(remoteStruct?.id) == docStruct.uuidString
                    expect(remoteStruct?.data) == docStruct.data.asString
                }

                context("with encryption") {
                    it("uploads existing documents") {
                        Configuration.encryptionEnabled = true

                        let networkCalls = APIRequest.callsCount
                        let promise: Promises.Promise<Bool> = sut.saveAllOnAPI()

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.then { success in
                                expect(success) == true
                                done()
                            }.catch { error in
                                fail("Should not happen: \(error)")
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        let remoteStruct = helper.fetchOnAPI(docStruct)
                        expect(remoteStruct?.id) == docStruct.uuidString
                        expect(remoteStruct?.data) == docStruct.data.asString
                        expect(remoteStruct?.encryptedData).to(match("encryptionName\":\"AES_GCM"))

                        Configuration.encryptionEnabled = false
                    }
                }
            }
        }

        describe(".refreshAllFromAPI()") {
            var docStruct: DocumentStruct!

            context("with encryption") {
                beforeEach {
                    BeamDate.freeze("2021-03-19T12:21:03Z")
                    Configuration.encryptionEnabled = true
                    docStruct = self.createStruct("Doc 1", "995d94e1-e0df-4eca-93e6-8778984bcd18", helper)
                    helper.saveRemotely(docStruct)
                }

                afterEach {
                    Configuration.encryptionEnabled = false
                    helper.deleteDocumentStruct(docStruct)
                    BeamDate.reset()
                }

                it("refreshes the local document") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.refreshAllFromAPI { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == true
                            done()
                        }
                    }
                    expect(APIRequest.callsCount - networkCalls) == 1
                }
            }

            context("with encryption and unencrypted content on the API side") {
                beforeEach {
                    docStruct = self.createStruct("Doc 1", "995d94e1-e0df-4eca-93e6-8778984bcd18", helper)
                    helper.saveRemotely(docStruct)
                }

                afterEach {
                    helper.deleteDocumentStruct(docStruct)
                }

                it("refreshes the local document") {
                    let networkCalls = APIRequest.callsCount

                    Configuration.encryptionEnabled = true

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.refreshAllFromAPI { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == true

                            if case .failure(let error) = result {
                                fail(error.localizedDescription)
                            }

                            done()
                        }
                    }
                    expect(APIRequest.callsCount - networkCalls) == 1

                    Configuration.encryptionEnabled = false
                }
            }


            context("when remote has the same updatedAt") {
                beforeEach {
                    BeamDate.freeze("2021-03-19T12:21:03Z")
                    docStruct = self.createStruct("Doc 1", "995d94e1-e0df-4eca-93e6-8778984bcd18", helper)
                    helper.saveRemotely(docStruct)
                }

                afterEach {
                    BeamDate.reset()
                    helper.deleteDocumentStruct(docStruct)
                }

                it("does not refreshes the local document") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.refreshAllFromAPI { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == true
                            done()
                        }
                    }
                    expect(APIRequest.callsCount - networkCalls) == 1
                }

                context("with encryption") {
                    it("refreshes the local document") {
                        Configuration.encryptionEnabled = true
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            sut.refreshAllFromAPI { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() } == true
                                done()
                            }
                        }
                        expect(APIRequest.callsCount - networkCalls) == 1
                        Configuration.encryptionEnabled = false
                    }
                }
            }

            context("with existing local document, another document existing on the API, both using same titles") {
                var remoteDocStruct: DocumentStruct!

                beforeEach {
                    Configuration.beamObjectAPIEnabled = false

                    docStruct = helper.createDocumentStruct(title: "foobar",
                                                            id: "995d94e1-e0df-4eca-93e6-8778984bcd18")

                    remoteDocStruct = helper.createDocumentStruct(title: docStruct.title,
                                                                  id: "00000000-e0df-4eca-93e6-8778984bcd18")
                    helper.saveRemotelyOnly(remoteDocStruct)
                }

                afterEach {
                    helper.deleteDocumentStruct(remoteDocStruct)
                }

                it("deletes the local document, fetch the remote document and saves it") {
                    let networkCalls = APIRequest.callsCount

                    var updateDocumentStruct: DocumentStruct?
                    var cancellable: AnyCancellable!
                    var callsOrder: [String] = []

                    waitUntil(timeout: .seconds(10)) { done in
                        cancellable = sut.onDocumentChange(docStruct) { updateDocumentStructCallback in
                            updateDocumentStruct = updateDocumentStructCallback
                            expect(updateDocumentStructCallback.id) == remoteDocStruct.id
                            callsOrder.append("onDocumentChange")
                            cancellable.cancel()
                        }

                        sut.refreshAllFromAPI { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == true

                            callsOrder.append("refreshAllFromAPI")
                            done()
                        }
                    }

                    expect(callsOrder) == ["onDocumentChange", "refreshAllFromAPI"]
                    expect(updateDocumentStruct?.id) == remoteDocStruct.id
                    expect(APIRequest.callsCount - networkCalls) == 1

                    let count = Document.rawCountWithPredicate(CoreDataManager.shared.mainContext,
                                                               NSPredicate(format: "title = %@", docStruct.title as CVarArg))
                    expect(count) == 1

                    let documents = try? Document.rawFetchAllWithLimit(CoreDataManager.shared.mainContext,
                                                                       NSPredicate(format: "title = %@", docStruct.title as CVarArg))

                    expect { documents?.compactMap { $0.id } } == [remoteDocStruct.id]
                }

                // TODO: Flaky test https://gitlab.com/beamgroup/beam/-/jobs/1529358097
                /*
                 [12:28:02]: ▸ BeamTests.DocumentManagerNetworkTests
                 2714[12:28:02]: ▸   _refreshAllFromAPI____with_existing_local_document__another_document_existing_on_the_API__both_using_same_titles__soft_deletes_the_local_document__fetch_the_remote_document_and_saves_it, failed - expected to equal <[995D94E1-E0DF-4ECA-93E6-8778984BCD18, 00000000-E0DF-4ECA-93E6-8778984BCD18]>, got <[00000000-E0DF-4ECA-93E6-8778984BCD18]>
                 2715[12:28:02]: ▸   /Users/administrator/builds/r_V1F-kB/0/beamgroup/beam/BeamTests/Managers/DocumentManagerNetworkTests.swift:418
                 2716[12:28:02]: ▸   ```
                 2717[12:28:02]: ▸                     // remote one replacing the original
                 2718[12:28:02]: ▸                     expect(callsIds) == ["995D94E1-E0DF-4ECA-93E6-8778984BCD18".uuid!,
                 2719[12:28:02]: ▸                                          "00000000-E0DF-4ECA-93E6-8778984BCD18".uuid!]
                 2720[12:28:02]: ▸   ```
                 2721[12:28:02]: ▸   _refreshAllFromAPI____with_existing_local_document__another_document_existing_on_the_API__both_using_same_titles__soft_deletes_the_local_document__fetch_the_remote_document_and_saves_it, failed - expected to equal <[onDocumentChange, onDocumentChange, refreshAllFromAPI]>, got <[onDocumentChange, refreshAllFromAPI]>
                 2722[12:28:02]: ▸   /Users/administrator/builds/r_V1F-kB/0/beamgroup/beam/BeamTests/Managers/DocumentManagerNetworkTests.swift:420
                 2723[12:28:02]: ▸   ```
                 2724[12:28:02]: ▸                                          "00000000-E0DF-4ECA-93E6-8778984BCD18".uuid!]
                 2725[12:28:02]: ▸                     expect(callsOrder) == ["onDocumentChange", "onDocumentChange", "refreshAllFromAPI"]
                 2726[12:28:02]: ▸                     expect(updateDocumentStruct?.id) == remoteDocStruct.id
                 2727[12:28:02]: ▸   ```
                 2728[12:28:02]: ▸   _refreshAllFromAPI____with_existing_local_document__another_document_existing_on_the_API__both_using_same_titles__soft_deletes_the_local_document__fetch_the_remote_document_and_saves_it, failed - expected to equal <[sign_in, delete_all_databases, delete_all_documents, update_document, documents, update_document]>, got <[sign_in, delete_all_databases, delete_all_documents, update_document, documents, delete_document]>
                 2729[12:28:02]: ▸   /Users/administrator/builds/r_V1F-kB/0/beamgroup/beam/BeamTests/Managers/DocumentManagerNetworkTests.swift:426
                 2730[12:28:02]: ▸   ```
                 2731[12:28:02]: ▸                                                 "update_document"]
                 2732[12:28:02]: ▸                     expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                 2733[12:28:02]: ▸                     expect(APIRequest.callsCount - networkCalls) == 2
                 2734[12:28:02]: ▸   ```
                 2735[12:28:02]: ▸   _refreshAllFromAPI____with_existing_local_document__another_document_existing_on_the_API__both_using_same_titles__soft_deletes_the_local_document__fetch_the_remote_document_and_saves_it, failed - expected to equal <2>, got <1>
                 2736[12:28:02]: ▸   /Users/administrator/builds/r_V1F-kB/0/beamgroup/beam/BeamTests/Managers/DocumentManagerNetworkTests.swift:431
                 2737[12:28:02]: ▸   ```
                 2738[12:28:02]: ▸                                                                NSPredicate(format: "title = %@", docStruct.title as CVarArg))
                 2739[12:28:02]: ▸                     expect(count) == 2
                 2740[12:28:02]: ▸
                 2741[12:28:02]: ▸   ```
                 2742[12:28:02]: ▸   _refreshAllFromAPI____with_existing_local_document__another_document_existing_on_the_API__both_using_same_titles__soft_deletes_the_local_document__fetch_the_remote_document_and_saves_it, failed - expected to be close to <2021-08-24 12:27:36.5580> (within 1), got <nil> (use beNil() to match nils)
                 2743[12:28:02]: ▸   /Users/administrator/builds/r_V1F-kB/0/beamgroup/beam/BeamTests/Managers/DocumentManagerNetworkTests.swift:434
                 2744[12:28:02]: ▸   ```
                 2745[12:28:02]: ▸                     let localDocument = try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct.id)
                 2746[12:28:02]: ▸                     expect(localDocument?.deleted_at).to(beCloseTo(BeamDate.now, within: 1.0))
                 2747[12:28:02]: ▸                 }
                 2748[12:28:02]: ▸   ```
                 2749[12:28:02]: ▸   _refreshAllFromAPI____with_existing_local_document__another_document_existing_on_the_API__both_using_same_titles__soft_deletes_the_local_document__fetch_the_remote_document_and_saves_it, failed - Expected network calls is different from current network calls
                 2750[12:28:02]: ▸   /Users/administrator/builds/r_V1F-kB/0/beamgroup/beam/BeamTests/Helpers/BeamTestsHelper.swift:60
                 2751[12:28:02]: ▸   ```
                 2752[12:28:02]: ▸             Logger.shared.logDebug("\nrm BeamTests/Vinyl/\(QuickSpec.current.name.c99ExtendedIdentifier)*", category: .network)
                 2753[12:28:02]: ▸             fail("Expected network calls is different from current network calls")
                 2754[12:28:02]: ▸         }
                 2755[12:28:02]: ▸   ```
                 2756[12:28:02]: ▸      Executed 629 tests, with 6 failures (0 unexpected) in 33.329 (33.455) seconds
                 2757
                 */
                it("soft deletes the local document, fetch the remote document and saves it") {
                    let networkCalls = APIRequest.callsCount

                    var updateDocumentStruct: DocumentStruct?
                    var cancellable: AnyCancellable!
                    var callsOrder: [String] = []
                    var callsIds: [UUID] = []

                    docStruct = helper.fillDocumentStructWithRandomText(docStruct)
                    docStruct = helper.saveLocally(docStruct)

                    cancellable = sut.onDocumentChange(docStruct) { updateDocumentStructCallback in
                        updateDocumentStruct = updateDocumentStructCallback
                        callsIds.append(updateDocumentStructCallback.id)
                        callsOrder.append("onDocumentChange")
                    }

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.refreshAllFromAPI { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == true

                            callsOrder.append("refreshAllFromAPI")
                            done()
                        }
                    }

                    cancellable.cancel()

                    // Will get 2 callbacks, for the first update when deleting the first local document, then for the
                    // remote one replacing the original
                    expect(callsIds) == ["995D94E1-E0DF-4ECA-93E6-8778984BCD18".uuid!,
                                         "00000000-E0DF-4ECA-93E6-8778984BCD18".uuid!]
                    expect(callsOrder) == ["onDocumentChange", "onDocumentChange", "refreshAllFromAPI"]
                    expect(updateDocumentStruct?.id) == remoteDocStruct.id

                    let expectedNetworkCalls = ["sign_in", "delete_all_databases",
                                                "delete_all_documents", "update_document", "documents",
                                                "update_document"]
                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                    expect(APIRequest.callsCount - networkCalls) == 2

                    let count = Document.rawCountWithPredicate(CoreDataManager.shared.mainContext,
                                                               NSPredicate(format: "title = %@", docStruct.title as CVarArg))
                    expect(count) == 2

                    let localDocument = try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct.id)
                    expect(localDocument?.deleted_at).to(beCloseTo(BeamDate.now, within: 1.0))
                }
            }

            context("when remote document doesn't exist") {
                beforeEach {
                    docStruct = self.createStruct("Doc 1", "995d94e1-e0df-4eca-93e6-8778984bcd18", helper)
                }

                it("flags the local document as deleted") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.refreshAllFromAPI { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == true
                            done()
                        }
                    }
                    expect(APIRequest.callsCount - networkCalls) == 1

                    let newDocStruct = sut.loadById(id: docStruct.id)
                    expect(newDocStruct).toNot(beNil())

                    expect(newDocStruct?.deletedAt).to(beCloseTo(BeamDate.now, within: 1.0))

                    let document = try? Document.fetchWithId(coreDataManager.mainContext, docStruct.id)
                    expect(document?.deleted_at).toNot(beNil())
                }

                context("when doing a delta sync") {
                    beforeEach {
                        Persistence.Sync.Documents.updated_at = BeamDate.now
                    }

                    it("does not flag the local document as deleted") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            sut.refreshAllFromAPI { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() } == true
                                done()
                            }
                        }
                        expect(APIRequest.callsCount - networkCalls) == 1

                        let newDocStruct = sut.loadById(id: docStruct.id)
                        expect(newDocStruct).toNot(beNil())

                        expect(newDocStruct?.deletedAt).to(beNil())

                        let document = try? Document.fetchWithId(coreDataManager.mainContext, docStruct.id)
                        expect(document?.deleted_at).to(beNil())
                    }
                }
            }

            context("when remote has a more recent updatedAt") {
                context("without conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4"
                    beforeEach {
                        docStruct = try? helper.createLocalAndRemoteVersions(ancestor,
                                                                             newRemote: newRemote,
                                                                             "995d94e1-e0df-4eca-93e6-8778984bcd18")
                    }

                    afterEach {
                        helper.deleteDocumentStruct(docStruct)
                    }

                    it("refreshes the local document") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.refreshAllFromAPI { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() } == true
                                done()
                            }
                        }
                        expect(APIRequest.callsCount - networkCalls) == 1
                        let newDocStruct = sut.loadById(id: docStruct.id)
                        expect(newDocStruct?.data) == newRemote.asData
                    }

                    context("with encryption") {
                        it("refreshes the local document") {
                            Configuration.encryptionEnabled = true
                            let networkCalls = APIRequest.callsCount
                            waitUntil(timeout: .seconds(10)) { done in
                                sut.refreshAllFromAPI { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() } == true
                                    done()
                                }
                            }
                            expect(APIRequest.callsCount - networkCalls) == 1
                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data) == newRemote.asData
                            Configuration.encryptionEnabled = false
                        }
                    }
                }

                context("with conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4\n"
                    let newLocal = "0\n1\n2\n3"
                    let merged = "0\n1\n2\n3\n4\n"

                    beforeEach {
                        helper.deleteAllDocuments()
                        docStruct = try? helper.createLocalAndRemoteVersions(ancestor,
                                                                             newLocal: newLocal,
                                                                             newRemote: newRemote,
                                                                             "995d94e1-e0df-4eca-93e6-8778984bcd18")
                    }

                    afterEach {
                        helper.deleteDocumentStruct(docStruct)
                    }

                    it("refreshes the local document") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.refreshAllFromAPI { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() } == true
                                done()
                            }
                        }
                        expect(APIRequest.callsCount - networkCalls) == 1

                        let newDocStruct = sut.loadById(id: docStruct.id)
                        expect(newDocStruct?.data.asString) == merged
                    }

                    context("with encryption") {
                        it("refreshes the local document") {
                            Configuration.encryptionEnabled = true
                            let networkCalls = APIRequest.callsCount
                            waitUntil(timeout: .seconds(10)) { done in
                                sut.refreshAllFromAPI { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() } == true
                                    done()
                                }
                            }
                            expect(APIRequest.callsCount - networkCalls) == 1

                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data.asString) == merged
                            Configuration.encryptionEnabled = false
                        }
                    }
                }
            }

            context("with non mergeable conflict") {
                let ancestor = "1\n2\n3\n"
                let newRemote = "0\n2\n3\n"
                let newLocal = "2\n2\n3\n"

                beforeEach {
                    docStruct = try? helper.createLocalAndRemoteVersions(ancestor,
                                                                         newLocal: newLocal,
                                                                         newRemote: newRemote,
                                                                         "995d94e1-e0df-4eca-93e6-8778984bcd18")
                }

                afterEach {
                    helper.deleteDocumentStruct(docStruct)
                }

                context("with Foundation") {
                    it("doesn't update the local document, returns error") {
                        let networkCalls = APIRequest.callsCount
                        waitUntil(timeout: .seconds(10)) { done in
                            sut.refreshAllFromAPI { result in
                                expect { try result.get() }.to(throwError { (error: DocumentManagerError) in
                                    expect(error) == DocumentManagerError.unresolvedConflict
                                })
                                done()
                            }
                        }
                        expect(APIRequest.callsCount - networkCalls) == 1

                        let newDocStruct = sut.loadById(id: docStruct.id)
                        expect(newDocStruct?.data.asString) == newLocal
                    }

                    context("with encryption") {
                        it("doesn't update the local document, returns error") {
                            Configuration.encryptionEnabled = true

                            let networkCalls = APIRequest.callsCount
                            waitUntil(timeout: .seconds(10)) { done in
                                sut.refreshAllFromAPI { result in
                                    expect { try result.get() }.to(throwError { (error: DocumentManagerError) in
                                        expect(error) == DocumentManagerError.unresolvedConflict
                                    })
                                    done()
                                }
                            }
                            expect(APIRequest.callsCount - networkCalls) == 1

                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data.asString) == newLocal

                            Configuration.encryptionEnabled = false
                        }
                    }
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

                    context("with encryption") {
                        it("doesn't refresh the local document") {
                            Configuration.encryptionEnabled = true

                            waitUntil(timeout: .seconds(10)) { done in
                                try? sut.refresh(docStruct) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() } == false
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1
                            Configuration.encryptionEnabled = false
                        }
                    }
                }

                context("with PromiseKit") {
                    it("doesn't refresh the local document") {
                        let promise: PromiseKit.Promise<Bool> = sut.refresh(docStruct)

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.done { refreshed in
                                expect(refreshed) == false
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1
                    }

                    context("with encryption") {
                        it("doesn't refresh the local document") {
                            Configuration.encryptionEnabled = true

                            let promise: PromiseKit.Promise<Bool> = sut.refresh(docStruct)

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { refreshed in
                                    expect(refreshed) == false
                                    done()
                                }.catch { fail("Should not be called: \($0)"); done() }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1
                            Configuration.encryptionEnabled = false
                        }
                    }
                }

                context("with Promises") {
                    it("doesn't refresh the local document") {
                        let promise: Promises.Promise<Bool> = sut.refresh(docStruct)

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.then { refreshed in
                                expect(refreshed) == false
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1
                    }

                    context("with encryption") {
                        it("doesn't refresh the local document") {
                            Configuration.encryptionEnabled = true

                            let promise: Promises.Promise<Bool> = sut.refresh(docStruct)

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { refreshed in
                                    expect(refreshed) == false
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1

                            Configuration.encryptionEnabled = false
                        }
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

                        context("with encryption") {
                            it("refreshes the local document") {
                                Configuration.encryptionEnabled = true

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

                                Configuration.encryptionEnabled = false
                            }
                        }
                    }

                    context("with PromiseKit") {
                        it("refreshes the local document") {
                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: PromiseKit.Promise<Bool> = sut.refresh(docStruct)
                                promise.done { refreshed in
                                    expect(refreshed) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)"); done() }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 2

                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data) == newRemote.asData
                        }
                    }

                    context("with Promises") {
                        it("refreshes the local document") {
                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: Promises.Promise<Bool> = sut.refresh(docStruct)
                                promise.then { refreshed in
                                    expect(refreshed) == true
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

                        context("with encryption") {
                            it("refreshes the local document") {
                                Configuration.encryptionEnabled = true

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

                                Configuration.encryptionEnabled = false
                            }
                        }
                    }

                    context("with PromiseKit") {
                        it("refreshes the local document") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: PromiseKit.Promise<Bool> = sut.refresh(docStruct)
                                promise.done { refreshed in
                                    expect(refreshed) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)"); done() }
                            }

                            expect([2, 5]).to(contain(APIRequest.callsCount - networkCalls))

                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data.asString) == merged
                        }
                    }

                    context("with Promises") {
                        it("refreshes the local document") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: Promises.Promise<Bool> = sut.refresh(docStruct)
                                promise.then { refreshed in
                                    expect(refreshed) == true
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

                context("with PromiseKit") {
                    it("doesn't refresh the local document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: PromiseKit.Promise<Bool> = sut.refresh(docStruct)
                            promise
                                .done { _ in }
                                .catch { error in
                                    expect(error).to(matchError(APIRequestError.notFound))
                                    done()
                                }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        let newDocStruct = sut.loadById(id: docStruct.id)
                        expect(newDocStruct?.deletedAt).toNot(beNil())
                    }
                }

                context("with Promises") {
                    it("doesn't refresh the local document") {
                        waitUntil(timeout: .seconds(10)) { done in
                            let promise: Promises.Promise<Bool> = sut.refresh(docStruct)
                            promise
                                .then { _ in }
                                .catch { error in
                                    expect(error).to(matchError(APIRequestError.notFound))
                                    done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        let newDocStruct = sut.loadById(id: docStruct.id)
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
                        context("with existing local document, another document existing on the API, both using same titles") {
                            var remoteDocStruct: DocumentStruct!

                            beforeEach {
                                docStruct = helper.createDocumentStruct(title: "foobar",
                                                                        id: "995d94e1-e0df-4eca-93e6-8778984bcd18")

                                remoteDocStruct = helper.createDocumentStruct(title: docStruct.title,
                                                                              id: "00000000-e0df-4eca-93e6-8778984bcd18")
                                helper.saveRemotelyOnly(remoteDocStruct)
                            }

                            it("deletes the local document, fetch the remote document and saves it") {
                                let previousNetworkCall = APIRequest.callsCount

                                var updateDocumentStruct: DocumentStruct?

                                var cancellable: AnyCancellable!
                                var callsOrder: [String] = []

                                cancellable = sut.onDocumentChange(docStruct) { updateDocumentStructCallback in
                                    updateDocumentStruct = updateDocumentStructCallback
                                    callsOrder.append("onDocumentChange")
                                }

                                waitUntil(timeout: .seconds(10)) { done in
                                    docStruct.version += 1
                                    sut.save(docStruct, true, { result in
                                        expect { try result.get() }.toNot(throwError())
                                        callsOrder.append("save")
                                        done()
                                    }, completion: nil)
                                }

                                cancellable.cancel()

                                expect(callsOrder) == ["onDocumentChange", "onDocumentChange", "save"]
                                expect(updateDocumentStruct?.id) == remoteDocStruct.id
                                expect(APIRequest.callsCount - previousNetworkCall) == 4

                                let count = Document.rawCountWithPredicate(CoreDataManager.shared.mainContext,
                                                                           NSPredicate(format: "title = %@", docStruct.title as CVarArg))
                                expect(count) == 1
                            }

                            it("soft deletes the local document, fetch the remote document and saves it") {
                                let previousNetworkCall = APIRequest.callsCount
                                var updateDocumentStruct: DocumentStruct?
                                var cancellable: AnyCancellable!
                                var callsOrder: [String] = []

                                docStruct = helper.fillDocumentStructWithRandomText(docStruct)
                                docStruct = helper.saveLocally(docStruct)

                                cancellable = sut.onDocumentChange(docStruct) { updateDocumentStructCallback in
                                    updateDocumentStruct = updateDocumentStructCallback
                                    callsOrder.append("onDocumentChange")
                                }

                                waitUntil(timeout: .seconds(10)) { done in
                                    docStruct.version += 1
                                    sut.save(docStruct, true, { result in
                                        expect { try result.get() }.toNot(throwError())
                                        callsOrder.append("save")
                                        done()
                                    }, completion: nil)
                                }
                                cancellable.cancel()

                                expect(callsOrder) == ["onDocumentChange", "onDocumentChange", "onDocumentChange", "save"]
                                expect(updateDocumentStruct?.id) == remoteDocStruct.id
                                expect(APIRequest.callsCount - previousNetworkCall) == 4

                                let count = Document.rawCountWithPredicate(CoreDataManager.shared.mainContext,
                                                                           NSPredicate(format: "title = %@", docStruct.title as CVarArg))
                                expect(count) == 2

                                let localDocument = try? Document.fetchWithId(CoreDataManager.shared.mainContext, docStruct.id)
                                expect(localDocument?.deleted_at).to(beCloseTo(BeamDate.now, within: 1.0))
                            }
                        }

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
                                expect(remoteStruct?.id) == docStruct.uuidString
                                expect(remoteStruct?.isPublic) == false
                            }

                            it("updates the database on the API") {
                                helper.saveRemotely(docStruct)
                                expect(docStruct.databaseId) == DatabaseManager.defaultDatabase.id
                                var remoteStruct = helper.fetchOnAPI(docStruct)
                                expect(remoteStruct?.database?.id) == DatabaseManager.defaultDatabase.uuidString

                                let newDatabase = helper.createDatabaseStruct("11111111-e0df-4eca-93e6-8778984bcd18")
                                helper.saveDatabaseLocally(newDatabase)
                                docStruct.databaseId = newDatabase.id

                                waitUntil(timeout: .seconds(10)) { done in
                                    sut.saveDocumentStructOnAPI(docStruct) { result in
                                        expect { try result.get() }.toNot(throwError())
                                        expect { try result.get() } == true
                                        done()
                                    }
                                }

                                remoteStruct = helper.fetchOnAPI(docStruct)
                                expect(remoteStruct?.database?.id) == newDatabase.uuidString
                            }

                            it("cancels previous unfinished saves") {
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

                            context("with a local deleted document") {
                                beforeEach { docStruct.deletedAt = BeamDate.now }

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

                        context("with encryption") {
                            beforeEach { Configuration.encryptionEnabled = true }
                            afterEach {
                                Configuration.encryptionEnabled = false
                            }
                            
                            it("saves the document on the API") {
                                waitUntil(timeout: .seconds(10)) { done in
                                    docStruct.version += 1
                                    sut.save(docStruct, true, { result in
                                        expect { try result.get() }.toNot(throwError())
                                        expect { try result.get() } == true
                                        done()
                                    }, completion: nil)
                                }

                                // Making sure the API side has encrypted data
                                let semaphore = DispatchSemaphore(value: 0)
                                _ = try? DocumentRequest().fetchDocument(docStruct.uuidString) { result in
                                    let documentAPIType = try? result.get()
                                    expect(documentAPIType?.encryptedData).to(match("encryptionName\":\"AES_GCM"))

                                    semaphore.signal()
                                }
                                semaphore.wait()

                                let savedDoc = helper.fetchOnAPI(docStruct)

                                // DocumentManager returns unencrypted data
                                expect(savedDoc?.id) == docStruct.uuidString
                                expect(savedDoc?.data?.hasPrefix("{ \"id\" : ")) == true
                            }

                            context("with public notes") {
                                beforeEach { docStruct.isPublic = true }

                                it("saves the document on the API") {
                                    waitUntil(timeout: .seconds(10)) { done in
                                        docStruct.version += 1
                                        sut.save(docStruct, true, { result in
                                            expect { try result.get() }.toNot(throwError())
                                            expect { try result.get() } == true
                                            done()
                                        }, completion: nil)
                                    }

                                    // Making sure the API side has *NOT* encrypted data
                                    let semaphore = DispatchSemaphore(value: 0)
                                    _ = try? DocumentRequest().fetchDocument(docStruct.uuidString) { result in
                                        let documentAPIType = try? result.get()
                                        expect(documentAPIType?.encryptedData).to(beNil())
                                        expect(documentAPIType?.data?.hasPrefix("{ \"id\" : \"995D94E1-E0DF-4ECA-93E6-8778984BCD18")) == true
                                        expect(documentAPIType?.isPublic) == true

                                        semaphore.signal()
                                    }
                                    semaphore.wait()
                                }
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
                            expect(remoteStruct?.id) == docStruct.uuidString
                            expect(remoteStruct?.isPublic) == false
                        }

                        it("updates the database on the API") {
                            helper.saveRemotely(docStruct)
                            var remoteStruct = helper.fetchOnAPI(docStruct)
                            expect(remoteStruct?.database?.id) == DatabaseManager.defaultDatabase.uuidString

                            let newDatabase = helper.createDatabaseStruct("11111111-e0df-4eca-93e6-8778984bcd18")
                            helper.saveDatabaseLocally(newDatabase)
                            docStruct.databaseId = newDatabase.id

                            let promise: PromiseKit.Promise<Bool> = sut.saveOnApi(docStruct)
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { success in
                                    expect(success) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)"); done() }
                            }

                            remoteStruct = helper.fetchOnAPI(docStruct)
                            expect(remoteStruct?.database?.id) == newDatabase.uuidString
                        }

                        it("cancels previous unfinished saves") {
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

                        context("with encryption") {
                            beforeEach { Configuration.encryptionEnabled = true }
                            afterEach {
                                Configuration.encryptionEnabled = false
                            }

                            it("saves the document on the API") {
                                let promise: PromiseKit.Promise<Bool> = sut.saveOnApi(docStruct)

                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.done { success in
                                        expect(success) == true
                                        done()
                                    }.catch { fail("Should not be called: \($0)"); done() }
                                }

                                // Making sure the API side has encrypted data
                                let semaphore = DispatchSemaphore(value: 0)
                                _ = try? DocumentRequest().fetchDocument(docStruct.uuidString) { result in
                                    let documentAPIType = try? result.get()
                                    expect(documentAPIType?.encryptedData).to(match("encryptionName\":\"AES_GCM"))

                                    semaphore.signal()
                                }
                                semaphore.wait()

                                let savedDoc = helper.fetchOnAPI(docStruct)

                                // DocumentManager returns unencrypted data
                                expect(savedDoc?.id) == docStruct.uuidString
                                expect(savedDoc?.data?.hasPrefix("{ \"id\" : ")) == true
                            }

                            context("with public notes") {
                                beforeEach { docStruct.isPublic = true }

                                it("saves the document on the API") {
                                    let promise: PromiseKit.Promise<Bool> = sut.saveOnApi(docStruct)

                                    waitUntil(timeout: .seconds(10)) { done in
                                        promise.done { success in
                                            expect(success) == true
                                            done()
                                        }.catch { fail("Should not be called: \($0)"); done() }
                                    }

                                    // Making sure the API side has encrypted data
                                    let semaphore = DispatchSemaphore(value: 0)
                                    _ = try? DocumentRequest().fetchDocument(docStruct.uuidString) { result in
                                        let documentAPIType = try? result.get()

                                        expect(documentAPIType?.encryptedData).to(beNil())
                                        expect(documentAPIType?.data?.hasPrefix("{ \"id\" : \"995D94E1-E0DF-4ECA-93E6-8778984BCD18")) == true
                                        expect(documentAPIType?.isPublic) == true

                                        semaphore.signal()
                                    }
                                    semaphore.wait()
                                }
                            }
                        }
                    }

                    context("with Promises") {
                        beforeEach {
                            docStruct = helper.saveLocally(docStruct)
                        }

                        it("saves the document on the API") {
                            let promise: Promises.Promise<Bool> = sut.saveOnApi(docStruct)

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { success in
                                    expect(success) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)"); done() }
                            }

                            let remoteStruct = helper.fetchOnAPI(docStruct)
                            expect(remoteStruct?.id) == docStruct.uuidString
                            expect(remoteStruct?.isPublic) == false
                        }

                        it("updates the database on the API") {
                            helper.saveRemotely(docStruct)
                            var remoteStruct = helper.fetchOnAPI(docStruct)
                            expect(remoteStruct?.database?.id) == DatabaseManager.defaultDatabase.uuidString

                            let newDatabase = helper.createDatabaseStruct("11111111-e0df-4eca-93e6-8778984bcd18")
                            helper.saveDatabaseLocally(newDatabase)
                            docStruct.databaseId = newDatabase.id

                            let promise: Promises.Promise<Bool> = sut.saveOnApi(docStruct)
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { success in
                                    expect(success) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)"); done() }
                            }

                            remoteStruct = helper.fetchOnAPI(docStruct)
                            expect(remoteStruct?.database?.id) == newDatabase.uuidString
                        }

                        it("cancels previous unfinished saves") {
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

                        context("with encryption") {
                            beforeEach { Configuration.encryptionEnabled = true }
                            afterEach {
                                Configuration.encryptionEnabled = false
                            }

                            it("saves the document on the API") {
                                let promise: Promises.Promise<Bool> = sut.saveOnApi(docStruct)

                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.then { success in
                                        expect(success) == true
                                        done()
                                    }.catch { fail("Should not be called: \($0)"); done() }
                                }

                                // Making sure the API side has encrypted data
                                let semaphore = DispatchSemaphore(value: 0)
                                _ = try? DocumentRequest().fetchDocument(docStruct.uuidString) { result in
                                    let documentAPIType = try? result.get()
                                    expect(documentAPIType?.encryptedData).to(match("encryptionName\":\"AES_GCM"))

                                    semaphore.signal()
                                }
                                semaphore.wait()

                                let savedDoc = helper.fetchOnAPI(docStruct)

                                // DocumentManager returns unencrypted data
                                expect(savedDoc?.id) == docStruct.uuidString
                                expect(savedDoc?.data?.hasPrefix("{ \"id\" : ")) == true
                            }

                            context("with public notes") {
                                beforeEach { docStruct.isPublic = true }

                                it("saves the document on the API") {
                                    let promise: Promises.Promise<Bool> = sut.saveOnApi(docStruct)

                                    waitUntil(timeout: .seconds(10)) { done in
                                        promise.then { success in
                                            expect(success) == true
                                            done()
                                        }.catch { fail("Should not be called: \($0)"); done() }
                                    }

                                    // Making sure the API side has encrypted data
                                    let semaphore = DispatchSemaphore(value: 0)
                                    _ = try? DocumentRequest().fetchDocument(docStruct.uuidString) { result in
                                        let documentAPIType = try? result.get()

                                        expect(documentAPIType?.encryptedData).to(beNil())
                                        expect(documentAPIType?.data?.hasPrefix("{ \"id\" : \"995D94E1-E0DF-4ECA-93E6-8778984BCD18")) == true
                                        expect(documentAPIType?.isPublic) == true

                                        semaphore.signal()
                                    }
                                    semaphore.wait()
                                }
                            }
                        }
                    }
                }

                context("with non mergeable conflict") {
                    let ancestor = "1\n2\n3\n"
                    let newRemote = "0\n2\n3\n"
                    let newLocal = "2\n2\n3\n"

                    beforeEach {
                        docStruct = try? helper.createLocalAndRemoteVersions(ancestor,
                                                                             newLocal: newLocal,
                                                                             newRemote: newRemote,
                                                                             "995d94e1-e0df-4eca-93e6-8778984bcd18")
                    }

                    afterEach {
                        helper.deleteDocumentStruct(docStruct)
                    }

                    context("with Foundation") {
                        it("updates the remote document with the local version") {
                            let localDocStruct = sut.loadById(id: docStruct.id)
                            // MD5 for ancestor string, making sure it's locally saved
                            expect(localDocStruct?.previousChecksum) == "c0710d6b4f15dfa88f600b0e6b624077"

                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                sut.saveDocumentStructOnAPI(docStruct) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() } == true

                                    // When this is failing randomly, rerun. This is because of the way
                                    // `BeamNote` saves document looking for links
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 3

                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data.asString) == newLocal
                            expect(helper.fetchOnAPIWithLatency(docStruct, newLocal)) == true
                        }

                        context("with encryption") {
                            it("updates the remote document with the local version") {
                                Configuration.encryptionEnabled = true

                                let networkCalls = APIRequest.callsCount

                                waitUntil(timeout: .seconds(10)) { done in
                                    docStruct.version += 1
                                    sut.save(docStruct, true, { result in
                                        expect { try result.get() }.toNot(throwError())
                                        expect { try result.get() } == true
                                        done()
                                    }, completion: nil)
                                }

                                // When this is failing randomly, rerun. This is because of the way
                                // `BeamNote` saves document looking for links
                                expect(APIRequest.callsCount - networkCalls) == 3

                                let newDocStruct = sut.loadById(id: docStruct.id)
                                expect(newDocStruct?.data.asString) == newLocal
                                expect(helper.fetchOnAPIWithLatency(docStruct, newLocal)) == true
                                Configuration.encryptionEnabled = false
                            }
                        }
                    }

                    context("with PromiseKit") {
                        it("updates the remote document with the local version") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: PromiseKit.Promise<Bool> = sut.saveOnApi(docStruct)

                                promise.done { success in
                                    expect(success) == true
                                    done()
                                }.catch { error in
                                    fail("Error: \(error)")
                                }
                            }

                            // When this is failing randomly, rerun. This is because of the way
                            // `BeamNote` saves document looking for links
                            expect(APIRequest.callsCount - networkCalls) == 3

                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data.asString) == newLocal
                            expect(helper.fetchOnAPIWithLatency(docStruct, newLocal)) == true
                        }

                        context("with encryption") {
                            it("updates the remote document with the local version") {
                                Configuration.encryptionEnabled = true

                                let networkCalls = APIRequest.callsCount

                                waitUntil(timeout: .seconds(10)) { done in
                                    let promise: PromiseKit.Promise<Bool> = sut.saveOnApi(docStruct)

                                    promise.done { success in
                                        expect(success) == true
                                        done()
                                    }.catch { error in
                                        fail("Error: \(error)")
                                    }
                                }

                                // When this is failing randomly, rerun. This is because of the way
                                // `BeamNote` saves document looking for links
                                expect(APIRequest.callsCount - networkCalls) == 3

                                let newDocStruct = sut.loadById(id: docStruct.id)
                                expect(newDocStruct?.data.asString) == newLocal
                                expect(helper.fetchOnAPIWithLatency(docStruct, newLocal)) == true

                                Configuration.encryptionEnabled = false
                            }
                        }
                    }

                    context("with Promises") {
                        it("updates the remote document with the local version") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: Promises.Promise<Bool> = sut.saveOnApi(docStruct)

                                promise.then { success in
                                    expect(success) == true
                                    done()
                                }.catch {
                                    fail("Error: \($0)")
                                }
                            }

                            // When this is failing randomly, rerun. This is because of the way
                            // `BeamNote` saves document looking for links
                            expect(APIRequest.callsCount - networkCalls) == 3

                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data.asString) == newLocal
                            expect(helper.fetchOnAPIWithLatency(docStruct, newLocal)) == true
                        }

                        context("with encryption") {
                            it("updates the remote document with the local version") {
                                Configuration.encryptionEnabled = true

                                let networkCalls = APIRequest.callsCount

                                waitUntil(timeout: .seconds(10)) { done in
                                    let promise: Promises.Promise<Bool> = sut.saveOnApi(docStruct)

                                    promise.then { success in
                                        expect(success) == true
                                        done()
                                    }.catch {
                                        fail("Error: \($0)")
                                    }
                                }

                                // When this is failing randomly, rerun. This is because of the way
                                // `BeamNote` saves document looking for links
                                expect(APIRequest.callsCount - networkCalls) == 3

                                let newDocStruct = sut.loadById(id: docStruct.id)
                                expect(newDocStruct?.data.asString) == newLocal
                                expect(helper.fetchOnAPIWithLatency(docStruct, newLocal)) == true

                                Configuration.encryptionEnabled = false
                            }
                        }
                    }
                }

                context("with mergeable conflict") {
                    let ancestor = "1\n2\n3"
                    let newRemote = "1\n2\n3\n4\n"
                    let newLocal = "0\n1\n2\n3"
                    let merged = "0\n1\n2\n3\n4\n"

                    beforeEach {
                        docStruct = try? helper.createLocalAndRemoteVersions(ancestor,
                                                                             newLocal: newLocal,
                                                                             newRemote: newRemote,
                                                                             "995d94e1-e0df-4eca-93e6-8778984bcd18")
                    }

                    afterEach {
                        helper.deleteDocumentStruct(docStruct)
                    }

                    context("with Foundation") {
                        it("updates the remote document") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                docStruct.version += 1
                                sut.save(docStruct, true, { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() } == true
                                    done()
                                }, completion: nil)
                            }

                            expect(APIRequest.callsCount - networkCalls) == 3

                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data.asString) == merged
                            expect(helper.fetchOnAPIWithLatency(docStruct, merged)) == true
                        }

                        context("with encryption") {
                            it("updates the remote document") {
                                Configuration.encryptionEnabled = true

                                let networkCalls = APIRequest.callsCount

                                waitUntil(timeout: .seconds(10)) { done in
                                    docStruct.version += 1
                                    sut.save(docStruct, true, { result in
                                        expect { try result.get() }.toNot(throwError())
                                        expect { try result.get() } == true
                                        done()
                                    }, completion: nil)
                                }

                                expect(APIRequest.callsCount - networkCalls) == 3

                                let newDocStruct = sut.loadById(id: docStruct.id)
                                expect(newDocStruct?.data.asString) == merged
                                expect(helper.fetchOnAPIWithLatency(docStruct, merged)) == true

                                Configuration.encryptionEnabled = false
                            }
                        }
                    }

                    context("with PromiseKit") {
                        it("updates the remote document") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: PromiseKit.Promise<Bool> = sut.saveOnApi(docStruct)

                                promise.done { success in
                                    expect(success) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)"); done() }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 3

                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data.asString) == merged
                            expect(helper.fetchOnAPIWithLatency(docStruct, merged)) == true
                        }

                        context("with encryption") {
                            it("updates the remote document") {
                                Configuration.encryptionEnabled = true

                                let networkCalls = APIRequest.callsCount

                                waitUntil(timeout: .seconds(10)) { done in
                                    let promise: PromiseKit.Promise<Bool> = sut.saveOnApi(docStruct)

                                    promise.done { success in
                                        expect(success) == true
                                        done()
                                    }.catch { fail("Should not be called: \($0)"); done() }
                                }

                                expect(APIRequest.callsCount - networkCalls) == 3

                                let newDocStruct = sut.loadById(id: docStruct.id)
                                expect(newDocStruct?.data.asString) == merged
                                expect(helper.fetchOnAPIWithLatency(docStruct, merged)) == true

                                Configuration.encryptionEnabled = false
                            }
                        }
                    }

                    context("with Promises") {
                        it("updates the remote document") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                let promise: Promises.Promise<Bool> = sut.saveOnApi(docStruct)

                                promise.then { success in
                                    expect(success) == true
                                    done()
                                }.catch { fail("Should not be called: \($0)"); done() }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 3

                            let newDocStruct = sut.loadById(id: docStruct.id)
                            expect(newDocStruct?.data.asString) == merged
                            expect(helper.fetchOnAPIWithLatency(docStruct, merged)) == true
                        }

                        context("with encryption") {
                            it("updates the remote document") {
                                Configuration.encryptionEnabled = true

                                let networkCalls = APIRequest.callsCount

                                waitUntil(timeout: .seconds(10)) { done in
                                    let promise: Promises.Promise<Bool> = sut.saveOnApi(docStruct)

                                    promise.then { success in
                                        expect(success) == true
                                        done()
                                    }.catch { fail("Should not be called: \($0)"); done() }
                                }

                                expect(APIRequest.callsCount - networkCalls) == 3

                                let newDocStruct = sut.loadById(id: docStruct.id)
                                expect(newDocStruct?.data.asString) == merged
                                expect(helper.fetchOnAPIWithLatency(docStruct, merged)) == true

                                Configuration.encryptionEnabled = false
                            }
                        }
                    }
                }
            }
        }

        describe("BeamObject API") {
            let beamObjectHelper: BeamObjectTestsHelper = BeamObjectTestsHelper()

            beforeEach {
                BeamDate.freeze("2021-03-19T12:21:03Z")
                Configuration.beamObjectAPIEnabled = true
            }

            afterEach {
                BeamDate.reset()
                Configuration.beamObjectAPIEnabled = false
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
