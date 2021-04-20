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

            sut = DatabaseManager()
            BeamTestsHelper.logout()
            sut.deleteAllDatabases(includedRemote: false) { _ in }

            beamHelper.beginNetworkRecording()
            helper = DocumentManagerTestsHelper(documentManager: DocumentManager(),
                                                coreDataManager: CoreDataManager.shared)

            BeamTestsHelper.login()
            helper.deleteAllDatabases()
            helper.deleteAllDocuments()

            try? EncryptionManager.shared.replacePrivateKey("j6tifPZTjUtGoz+1RJkO8dOMlu48MUUSlwACw/fCBw0=")
        }

        afterEach {
            beamHelper.endNetworkRecording()
            Configuration.encryptionEnabled = false
        }

        describe(".syncDatabases()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
            }
            describe("when remote database doesn't exist") {
                beforeEach {
                    helper.saveDatabaseLocally(dbStruct)
                }

                context("with Foundation") {
                    it("creates remote database") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            sut.syncDatabases { result in
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

                        let promise: PromiseKit.Promise<Bool> = sut.syncDatabases()

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

                        let promise: Promises.Promise<Bool> = sut.syncDatabases()

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
                            sut.syncDatabases { result in
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

                        let promise: PromiseKit.Promise<Bool> = sut.syncDatabases()

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

                        let promise: Promises.Promise<Bool> = sut.syncDatabases()

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

        describe(".saveDatabase()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
            }

            context("with Foundation") {
                it("saves database") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.saveDatabase(dbStruct, true, { result in
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

                    let promise: PromiseKit.Promise<Bool> = sut.saveDatabase(dbStruct)

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

                    let promise: Promises.Promise<Bool> = sut.saveDatabase(dbStruct)

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

        describe(".deleteDatabase()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
                helper.saveDatabaseLocally(dbStruct)
                helper.saveDatabaseRemotely(dbStruct)
            }

            context("with Foundation") {
                it("deletes database") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.deleteDatabase(dbStruct) { result in
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

                    let promise: PromiseKit.Promise<Bool> = sut.deleteDatabase(dbStruct)

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

                    let promise: Promises.Promise<Bool> = sut.deleteDatabase(dbStruct)

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

        describe(".deleteAllDatabases()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
                helper.saveDatabaseLocally(dbStruct)
                helper.saveDatabaseRemotely(dbStruct)
            }

            context("with Foundation") {
                it("deletes databases") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.deleteAllDatabases { result in
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

                    let promise: PromiseKit.Promise<Bool> = sut.deleteAllDatabases()

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

                    let promise: Promises.Promise<Bool> = sut.deleteAllDatabases()

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

        describe(".uploadAllDatabases()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
                helper.saveDatabaseLocally(dbStruct)
            }

            afterEach {
                assert(AuthenticationManager.shared.isAuthenticated)
                helper.deleteDatabaseStruct(dbStruct)
            }

            context("with Foundation") {
                it("uploads existing databases") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.uploadAllDatabases { result in
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

                    let promise: PromiseKit.Promise<Bool> = sut.uploadAllDatabases()

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

                    let promise: Promises.Promise<Bool> = sut.uploadAllDatabases()

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

        describe(".fetchDatabases()") {
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
                        sut.fetchDatabases { result in
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
                    let promise: PromiseKit.Promise<Bool> = sut.fetchDatabases()

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
                    let promise: Promises.Promise<Bool> = sut.fetchDatabases()

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
    }
}
