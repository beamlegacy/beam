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

class DatabaseManagerNetworkTests: QuickSpec {
    override func spec() {
        var coreDataManager: CoreDataManager!
        var sut: DatabaseManager!
        var helper: DocumentManagerTestsHelper!
        let beamHelper = BeamTestsHelper()
        let fixedDate = "2021-03-19T12:21:03Z"

        beforeEach {
            BeamDate.freeze(fixedDate)

            coreDataManager = CoreDataManager()
            // Setup CoreData
            coreDataManager.setupWithoutMigration()
            CoreDataManager.shared = coreDataManager
            sut = DatabaseManager(coreDataManager: coreDataManager)

            BeamTestsHelper.logout()
            sut.deleteAll(includedRemote: false) { _ in }

            beamHelper.beginNetworkRecording()

            helper = DocumentManagerTestsHelper(documentManager: DocumentManager(),
                                                coreDataManager: CoreDataManager.shared)

            BeamTestsHelper.login()
            helper.deleteAllDatabases()
            helper.deleteAllDocuments()

            Configuration.beamObjectDirectCall = false

            try? EncryptionManager.shared.replacePrivateKey(Configuration.testPrivateKey)
        }

        afterEach {
            beamHelper.endNetworkRecording()
            BeamDate.reset()
        }

        describe(".save()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
            }

            afterEach {
                helper.deleteDatabaseStruct(dbStruct)
            }

            context("with Foundation") {
                it("saves database") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.save(dbStruct, true, { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == true
                            done()
                        })
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1

                    let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                    expect(remoteStruct?.id) == dbStruct.id
                    let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 1
                }
            }

            context("with PromiseKit") {
                it("saves database") {
                    let networkCalls = APIRequest.callsCount

                    let promise: PromiseKit.Promise<Bool> = sut.save(dbStruct)

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.done { success in
                            expect(success) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1

                    let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                    expect(remoteStruct?.id) == dbStruct.id
                    let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 1
                }
            }

            context("with Promises") {
                it("saves database") {
                    let networkCalls = APIRequest.callsCount

                    let promise: Promises.Promise<Bool> = sut.save(dbStruct)

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.then { success in
                            expect(success) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1

                    let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                    expect(remoteStruct?.id) == dbStruct.id
                    let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 1
                }
            }
        }

        describe(".delete()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
                helper.saveDatabaseLocally(dbStruct)
                helper.saveDatabaseRemotely(dbStruct)
            }

            afterEach {
                helper.deleteDatabaseStruct(dbStruct)
            }

            context("with Foundation") {
                it("deletes database") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.delete(dbStruct) { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == true
                            done()
                        }
                    }

                    let expectedNetworkCalls = ["sign_in", "delete_all_beam_objects", "delete_all_beam_objects", "update_beam_object", "delete_beam_object"]
                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                    let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                    expect(remoteStruct).to(beNil())
                }
            }

            context("with PromiseKit") {
                it("deletes database") {
                    let networkCalls = APIRequest.callsCount

                    let promise: PromiseKit.Promise<Bool> = sut.delete(dbStruct)

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.done { success in
                            expect(success) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }
                    expect(APIRequest.callsCount - networkCalls) == 1

                    let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                    expect(remoteStruct).to(beNil())
                }
            }

            context("with Promises") {
                it("deletes database") {
                    let networkCalls = APIRequest.callsCount

                    let promise: Promises.Promise<Bool> = sut.delete(dbStruct)

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.then { success in
                            expect(success) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }
                    expect(APIRequest.callsCount - networkCalls) == 1

                    let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                    expect(remoteStruct).to(beNil())
                }
            }
        }

        describe(".deleteAll()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
                helper.saveDatabaseLocally(dbStruct)
                helper.saveDatabaseRemotely(dbStruct)
            }

            afterEach {
                helper.deleteDatabaseStruct(dbStruct)
            }

            context("with Foundation") {
                it("deletes databases") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.deleteAll { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == true
                            done()
                        }
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1
                    let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                    expect(remoteStruct).to(beNil())
                }
            }

            context("with PromiseKit") {
                it("deletes databases") {
                    let networkCalls = APIRequest.callsCount

                    let promise: PromiseKit.Promise<Bool> = sut.deleteAll()

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.done { success in
                            expect(success) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1
                    let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                    expect(remoteStruct).to(beNil())
                }
            }

            context("with Promises") {
                it("deletes databases") {
                    let networkCalls = APIRequest.callsCount

                    let promise: Promises.Promise<Bool> = sut.deleteAll()

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.then { success in
                            expect(success) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1
                    let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                    expect(remoteStruct).to(beNil())
                }
            }
        }

        describe(".saveAllOnApi()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
                helper.saveDatabaseLocally(dbStruct)
            }

            afterEach {
                helper.deleteDatabaseStruct(dbStruct)
            }

            context("with Foundation") {
                it("uploads existing databases") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.saveAllOnApi { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == true
                            done()
                        }
                    }
                    expect(APIRequest.callsCount - networkCalls) == 1

                    let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                    expect(remoteStruct?.id) == dbStruct.id
                }
            }

            context("with PromiseKit") {
                it("uploads existing databases") {
                    let networkCalls = APIRequest.callsCount

                    let promise: PromiseKit.Promise<Bool> = sut.saveAllOnApi()

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.done { success in
                            expect(success) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }
                    expect(APIRequest.callsCount - networkCalls) == 1

                    let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                    expect(remoteStruct?.id) == dbStruct.id
                }
            }

            context("with Promises") {
                it("uploads existing databases") {
                    let networkCalls = APIRequest.callsCount

                    let promise: Promises.Promise<Bool> = sut.saveAllOnApi()

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.then { success in
                            expect(success) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }
                    expect(APIRequest.callsCount - networkCalls) == 1

                    let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                    expect(remoteStruct?.id) == dbStruct.id
                }
            }
        }

        describe(".fetchAllOnApi()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                // This will delete the default database created, and switch the new we received to the default one. It
                // will generate networks calls (delete the default on the server side) which makes harder to test
                Configuration.shouldDeleteEmptyDatabase = false

                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
                helper.saveDatabaseLocally(dbStruct)
                helper.saveDatabaseRemotely(dbStruct)
                helper.deleteDatabaseStruct(dbStruct, includedRemote: false)
            }

            afterEach {
                helper.deleteDatabaseStruct(dbStruct)
                Configuration.shouldDeleteEmptyDatabase = true
            }

            context("with Foundation") {
                it("fetches all databases") {
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

                    let expectedNetworkCalls = [Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_objects_data_url" : "beam_objects"]
                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                    expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                    let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 1
                }
            }

            context("with PromiseKit") {
                it("fetches all databases") {
                    let networkCalls = APIRequest.callsCount
                    let promise: PromiseKit.Promise<Bool> = sut.fetchAllOnApi()

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.done { success in
                            expect(success) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }

                    let expectedNetworkCalls = ["beam_objects"]
                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                    expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                    let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 1
                }
            }

            context("with Promises") {
                it("fetches all databases") {
                    let networkCalls = APIRequest.callsCount
                    let promise: Promises.Promise<Bool> = sut.fetchAllOnApi()

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.then { success in
                            expect(success) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }

                    let expectedNetworkCalls = ["beam_objects"]
                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                    expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                    let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 1
                }
            }
        }

        describe("BeamObject API") {
            let beamObjectHelper: BeamObjectTestsHelper = BeamObjectTestsHelper()

            beforeEach {
                // Must freeze time as `checksum` takes createdAt/updatedAt/deletedAt into consideration
                BeamDate.freeze("2021-03-19T12:21:03Z")
            }

            afterEach {
                BeamDate.reset()
            }

            describe("saveOnBeamObjectAPI()") {
                var dbStruct: DatabaseStruct!
                beforeEach {
                    dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
                    helper.saveDatabaseLocally(dbStruct)
                }

                afterEach {
                    helper.deleteDatabaseStruct(dbStruct)
                    beamObjectHelper.delete( dbStruct)
                }

                context("Foundation") {
                    it("saves as beamObject") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                try sut.saveOnBeamObjectAPI(dbStruct) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() } == dbStruct
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        let remoteObject: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct)
                        expect(remoteObject) == dbStruct
                    }
                }
                context("PromiseKit") {
                    it("saves as beamObject") {
                        let promise: PromiseKit.Promise<DatabaseStruct> = sut.saveOnBeamObjectAPI(dbStruct)

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.done { receivedDbStruct in
                                expect(receivedDbStruct) == dbStruct
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        let remoteObject: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct)
                        expect(remoteObject) == dbStruct
                    }
                }
                context("Promises") {
                    it("saves as beamObject") {
                        let promise: Promises.Promise<DatabaseStruct> = sut.saveOnBeamObjectAPI(dbStruct)

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.then { receivedDbStruct in
                                expect(receivedDbStruct) == dbStruct
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        let remoteObject: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct)
                        expect(remoteObject) == dbStruct
                    }
                }
            }

            describe("saveOnBeamObjectsAPI()") {
                var dbStruct: DatabaseStruct!
                var dbStruct2: DatabaseStruct!
                beforeEach {
                    dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29", "Database 1")
                    helper.saveDatabaseLocally(dbStruct)

                    dbStruct2 = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd39", "Database 2")
                    helper.saveDatabaseLocally(dbStruct2)
                }

                afterEach {
                    beamObjectHelper.delete(dbStruct)
                    beamObjectHelper.delete(dbStruct2)
                }

                context("Foundation") {
                    it("saves as beamObjects") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                let objects: [DatabaseStruct] = [dbStruct, dbStruct2]

                                _ = try sut.saveOnBeamObjectsAPI(objects) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    expect { try result.get() } == objects
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        let remoteObject1: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct)
                        expect(remoteObject1) == dbStruct

                        let remoteObject2: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct2)
                        expect(remoteObject2) == dbStruct2
                    }
                }
                context("PromiseKit") {
                    it("saves as beamObjects") {
                        let objects: [DatabaseStruct] = [dbStruct, dbStruct2]
                        let promise: PromiseKit.Promise<[DatabaseStruct]> = sut.saveOnBeamObjectsAPI(objects)

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.done { receivedObjects in
                                expect(receivedObjects) == objects
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        let remoteObject1: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct)
                        expect(remoteObject1) == dbStruct

                        let remoteObject2: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct2)
                        expect(remoteObject2) == dbStruct2
                    }
                }
                context("Promises") {
                    it("saves as beamObjects") {
                        let objects: [DatabaseStruct] = [dbStruct, dbStruct2]
                        let promise: Promises.Promise<[DatabaseStruct]> = sut.saveOnBeamObjectsAPI(objects)

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.then { receivedObjects in
                                expect(receivedObjects) == objects
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        let remoteObject1: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct)
                        expect(remoteObject1) == dbStruct

                        let remoteObject2: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct2)
                        expect(remoteObject2) == dbStruct2
                    }
                }
            }

            describe("saveAllOnBeamObjectApi()") {
                var dbStruct: DatabaseStruct!
                var dbStruct2: DatabaseStruct!
                beforeEach {
                    dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29", "Database 1")
                    helper.saveDatabaseLocally(dbStruct)

                    dbStruct2 = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd39", "Database 2")
                    helper.saveDatabaseLocally(dbStruct2)
                }

                afterEach {
                    beamObjectHelper.delete(dbStruct)
                    beamObjectHelper.delete(dbStruct2)
                }

                context("Foundation") {
                    it("saves as beamObjects") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveAllOnBeamObjectApi { result in
                                    expect { try result.get() }.toNot(throwError())
                                    let documentsCount = try? result.get()

                                    expect(documentsCount?.0) == 2
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        let remoteObject1: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct)
                        expect(remoteObject1) == dbStruct

                        let remoteObject2: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct2)
                        expect(remoteObject2) == dbStruct2
                    }
                }
                context("PromiseKit") {
                    it("saves as beamObjects") {
                        let promise: PromiseKit.Promise<[DatabaseStruct]> = sut.saveAllOnBeamObjectApi()

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.done { documents in
                                expect(documents).to(haveCount(2))
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        let remoteObject1: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct)
                        expect(remoteObject1) == dbStruct

                        let remoteObject2: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct2)
                        expect(remoteObject2) == dbStruct2
                    }
                }
                context("Promises") {
                    it("saves as beamObjects") {
                        let promise: Promises.Promise<[DatabaseStruct]> = sut.saveAllOnBeamObjectApi()

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.then { documents in
                                expect(documents).to(haveCount(2))
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        let remoteObject1: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct)
                        expect(remoteObject1) == dbStruct

                        let remoteObject2: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct2)
                        expect(remoteObject2) == dbStruct2
                    }
                }
            }

            describe("receivedObjects()") {
                var dbStruct: DatabaseStruct!
                var dbStruct2: DatabaseStruct!
                let newTitle1 = "Database 3"
                let newTitle2 = "Database 4"

                beforeEach {
                    BeamDate.freeze("2021-03-19T12:21:03Z")

                    dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29", "Database 1")
                    dbStruct2 = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd39", "Database 2")

                    // Avoid trigger a delete of the new defaultDatabase
                    helper.deleteDatabaseStruct(DatabaseManager.defaultDatabase, includedRemote: false)
                }

                afterEach {
                    helper.deleteDatabaseStruct(dbStruct, includedRemote: true)
                    helper.deleteDatabaseStruct(dbStruct2, includedRemote: true)
                }

                context("without any locally saved databases") {
                    beforeEach {
                        helper.deleteDatabaseStruct(dbStruct, includedRemote: true)
                        helper.deleteDatabaseStruct(dbStruct2, includedRemote: true)

                        // Default database is first updatedAt
                        BeamDate.travel(2)
                        dbStruct2.updatedAt = BeamDate.now
                    }

                    context("with 2 databases with same titles") {
                        beforeEach {
                            dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29", "Database 1")
                            dbStruct2 = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd39", "Database 1")
                        }

                        it("saves them locally, change the title and save it remotely") {
                            try sut.receivedObjects([dbStruct, dbStruct2])

                            let expectedNetworkCalls = ["update_beam_objects"]

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            expect(1) == Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                                     NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                            expect(1) == Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                                     NSPredicate(format: "id = %@", dbStruct2.id as CVarArg))

                            expect(try? Database.fetchWithId(CoreDataManager.shared.mainContext, dbStruct.id)?.title) == dbStruct.title

                            let remoteObject1: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct)
                            expect(remoteObject1).to(beNil())

                            let remoteObject2: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct2)
                            dbStruct2.title = "\(dbStruct2.title) (2)"
                            expect(remoteObject2) == dbStruct2

                            expect(try? Database.fetchWithId(CoreDataManager.shared.mainContext, dbStruct2.id)?.title) == dbStruct2.title
                        }
                    }
                }

                context("with local databases saved") {
                    beforeEach {
                        dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29", "Database 1")
                        dbStruct2 = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd39", "Database 2")

                        helper.saveDatabaseLocally(dbStruct)
                        helper.saveDatabaseLocally(dbStruct2)

                        // Prevent the triggering of deleting the automatically created default Database
                        Persistence.Database.currentDatabaseId = dbStruct.id
                    }

                    afterEach {
                        Persistence.Database.currentDatabaseId = nil
                    }

                    context("with 2 databases with different titles") {
                        beforeEach {
                            dbStruct.title = newTitle1
                            dbStruct2.title = newTitle2
                        }

                        it("saves to local objects") {
                            let networkCalls = APIRequest.callsCount

                            try sut.receivedObjects([dbStruct, dbStruct2])

                            expect(APIRequest.callsCount - networkCalls) == 0

                            expect(Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                               NSPredicate(format: "id = %@", dbStruct.id as CVarArg))) == 1

                            expect(Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                               NSPredicate(format: "id = %@", dbStruct2.id as CVarArg))) == 1

                            expect(try? Database.fetchWithId(CoreDataManager.shared.mainContext, dbStruct.id)?.title) == dbStruct.title

                            expect(try? Database.fetchWithId(CoreDataManager.shared.mainContext, dbStruct2.id)?.title) == dbStruct2.title
                        }
                    }

                    context("with 2 databases with same titles") {
                        beforeEach {
                            dbStruct.title = newTitle1
                            dbStruct2.title = newTitle1
                        }

                        it("saves to local objects and save it remotely") {
                            let networkCalls = APIRequest.callsCount

                            try sut.receivedObjects([dbStruct, dbStruct2])

                            expect(APIRequest.callsCount - networkCalls) == 1

                            let expectedNetworkCalls = ["update_beam_objects"]
                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            expect(1) == Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                                     NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                            expect(1) == Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                                     NSPredicate(format: "id = %@", dbStruct2.id as CVarArg))

                            expect(try? Database.fetchWithId(CoreDataManager.shared.mainContext, dbStruct.id)?.title) == dbStruct.title

                            let remoteObject1: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct)
                            expect(remoteObject1).to(beNil())

                            let remoteObject2: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct2)
                            dbStruct2.title = "\(newTitle1) (2)"
                            expect(remoteObject2) == dbStruct2

                            expect(try? Database.fetchWithId(CoreDataManager.shared.mainContext, dbStruct2.id)?.title) == dbStruct2.title
                        }
                    }
                }
            }
        }
    }
}
