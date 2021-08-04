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
class DatabaseManagerNetworkTests: QuickSpec {
    override func spec() {
        var sut: DatabaseManager!
        var helper: DocumentManagerTestsHelper!
        let beamHelper = BeamTestsHelper()

        beforeEach {
            Configuration.encryptionEnabled = true
            Configuration.beamObjectAPIEnabled = false

            sut = DatabaseManager()
            BeamTestsHelper.logout()
            sut.deleteAll(includedRemote: false) { _ in }

            beamHelper.beginNetworkRecording()

            helper = DocumentManagerTestsHelper(documentManager: DocumentManager(),
                                                coreDataManager: CoreDataManager.shared)

            BeamTestsHelper.login()
            helper.deleteAllDatabases()
            helper.deleteAllDocuments()

            try? EncryptionManager.shared.replacePrivateKey(Configuration.testPrivateKey)
        }

        afterEach {
            beamHelper.endNetworkRecording()
            Configuration.encryptionEnabled = false
        }

        describe(".syncAll()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
            }
            describe("when remote database doesn't exist") {
                beforeEach {
                    helper.saveDatabaseLocally(dbStruct)
                }

                afterEach {
                    helper.deleteDatabaseStruct(dbStruct)
                }

                context("with Foundation") {
                    it("creates remote database") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            sut.syncAll { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() } == true
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 2
                        let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                        expect(remoteStruct?.id) == dbStruct.uuidString
                    }
                }

                context("with PromiseKit") {
                    it("creates remote database") {
                        let networkCalls = APIRequest.callsCount

                        let promise: PromiseKit.Promise<Bool> = sut.syncAll()

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.done { success in
                                expect(success) == true
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 2
                        let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                        expect(remoteStruct?.id) == dbStruct.uuidString
                    }
                }

                context("with Promises") {
                    it("creates remote database") {
                        let networkCalls = APIRequest.callsCount

                        let promise: Promises.Promise<Bool> = sut.syncAll()

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.then { success in
                                expect(success) == true
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 2
                        let remoteStruct = helper.fetchDatabaseOnAPI(dbStruct)
                        expect(remoteStruct?.id) == dbStruct.uuidString
                    }
                }
            }

            describe("when local database doesn't exist") {
                beforeEach {
                    helper.saveDatabaseLocally(dbStruct)
                    helper.saveDatabaseRemotely(dbStruct)
                    helper.deleteDatabaseStruct(dbStruct, includedRemote: false)
                }

                context("with Foundation") {
                    it("creates local database") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            sut.syncAll { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() } == true
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 2
                        let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                                NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                        expect(count) == 1
                    }
                }

                context("with PromiseKit") {
                    it("creates local database") {
                        let networkCalls = APIRequest.callsCount

                        let promise: PromiseKit.Promise<Bool> = sut.syncAll()

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.done { success in
                                expect(success) == true
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 2
                        let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                                NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                        expect(count) == 1
                    }
                }

                context("with Promises") {
                    it("creates local database") {
                        let networkCalls = APIRequest.callsCount

                        let promise: Promises.Promise<Bool> = sut.syncAll()

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.then { success in
                                expect(success) == true
                                done()
                            }.catch { fail("Should not be called: \($0)"); done() }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 2
                        let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                                NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                        expect(count) == 1
                    }
                }
            }
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
                    expect(remoteStruct?.id) == dbStruct.uuidString
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
                    expect(remoteStruct?.id) == dbStruct.uuidString
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
                    expect(remoteStruct?.id) == dbStruct.uuidString
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
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.delete(id: dbStruct.id) { result in
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
                    expect(remoteStruct?.id) == dbStruct.uuidString
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
                    expect(remoteStruct?.id) == dbStruct.uuidString
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
                    expect(remoteStruct?.id) == dbStruct.uuidString
                }
            }
        }

        describe(".fetchAllOnApi()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
                helper.saveDatabaseLocally(dbStruct)
                helper.saveDatabaseRemotely(dbStruct)
                helper.deleteDatabaseStruct(dbStruct, includedRemote: false)
            }

            afterEach {
                helper.deleteDatabaseStruct(dbStruct)
            }

            context("with Foundation") {
                it("fetches all databases") {
                    let networkCalls = APIRequest.callsCount
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.fetchAllOnApi { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == true
                            done()
                        }
                    }
                    expect(APIRequest.callsCount - networkCalls) == 1
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
                    expect(APIRequest.callsCount - networkCalls) == 1
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
                    expect(APIRequest.callsCount - networkCalls) == 1
                    let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 1
                }
            }
        }

        describe("BeamObject API") {
            let beamObjectHelper: BeamObjectTestsHelper = BeamObjectTestsHelper()

            beforeEach {
                Configuration.beamObjectAPIEnabled = true

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
                    beamObjectHelper.delete(dbStruct.id)
                }

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

                    let remoteObject: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct.beamObjectId)
                    expect(remoteObject) == dbStruct
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
                    beamObjectHelper.delete(dbStruct.id)
                    beamObjectHelper.delete(dbStruct2.id)
                }

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

                    let remoteObject1: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct.beamObjectId)
                    expect(remoteObject1) == dbStruct

                    let remoteObject2: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct2.beamObjectId)
                    expect(remoteObject2) == dbStruct2
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
                    beamObjectHelper.delete(dbStruct.id)
                    beamObjectHelper.delete(dbStruct2.id)
                }

                it("saves as beamObjects") {
                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.saveAllOnBeamObjectApi { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get() } == true
                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }

                    let remoteObject1: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct.beamObjectId)
                    expect(remoteObject1) == dbStruct

                    let remoteObject2: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct2.beamObjectId)
                    expect(remoteObject2) == dbStruct2
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
                }

                afterEach {
                    helper.deleteDatabaseStruct(dbStruct, includedRemote: true)
                    helper.deleteDatabaseStruct(dbStruct2, includedRemote: true)
                }

                context("without any locally saved databases") {
                    beforeEach {
                        helper.deleteDatabaseStruct(dbStruct, includedRemote: true)
                        helper.deleteDatabaseStruct(dbStruct2, includedRemote: true)
                    }

                    context("with 2 databases with different titles") {
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
                            dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29", "Database 1")
                            dbStruct2 = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd39", "Database 1")
                        }

                        it("saves them locally, change the title and save it remotely") {
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

                            let remoteObject1: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct.beamObjectId)
                            expect(remoteObject1).to(beNil())

                            let remoteObject2: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct2.beamObjectId)
                            dbStruct2.title = "\(dbStruct2.title) 2"
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

                            let remoteObject1: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct.beamObjectId)
                            expect(remoteObject1).to(beNil())

                            let remoteObject2: DatabaseStruct? = try? beamObjectHelper.fetchOnAPI(dbStruct2.beamObjectId)
                            dbStruct2.title = "\(newTitle1) 2"
                            expect(remoteObject2) == dbStruct2

                            expect(try? Database.fetchWithId(CoreDataManager.shared.mainContext, dbStruct2.id)?.title) == dbStruct2.title
                        }
                    }
                }
            }
        }
    }
}
