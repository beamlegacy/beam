// swiftlint:disable file_length

import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import PromiseKit
import Promises

@testable import Beam
// swiftlint:disable:next type_body_length
class DatabaseManagerTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        var sut: DatabaseManager!
        let mainContext = CoreDataManager.shared.mainContext
        var helper: DocumentManagerTestsHelper!

        beforeEach {
            helper = DocumentManagerTestsHelper(documentManager: DocumentManager(),
                                                coreDataManager: CoreDataManager.shared)
            sut = DatabaseManager()
            BeamTestsHelper.logout()
            sut.deleteAll(includedRemote: false) { _ in }
        }

        describe(".defaultDatabase()") {
            it("create a default database only once") {
                _ = DatabaseManager.defaultDatabase
                _ = DatabaseManager.defaultDatabase
                let database = DatabaseManager.defaultDatabase

                expect(database.id) == DatabaseManager.defaultDatabase.id
                expect(database.title) == "Default"
                expect(Database.countWithPredicate(mainContext)) == 1
            }
        }

        describe("deleteCurrentDatabaseIfEmpty()") {
            var dbStruct: DatabaseStruct!
            var dbStruct2: DatabaseStruct!

            beforeEach {
                try? Database.deleteWithPredicate(CoreDataManager.shared.mainContext)

                dbStruct2 = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29", "Real DB")

                dbStruct = helper.createDatabaseStruct("195d94e1-e0df-4eca-93e6-8778984bcd29", "Default 1")
                helper.saveDatabaseLocally(dbStruct)
            }

            afterEach {
                helper.deleteDatabaseStruct(dbStruct, includedRemote: true)
                helper.deleteDatabaseStruct(dbStruct2, includedRemote: true)
            }

            it("deletes current Database and switch") {
                Persistence.Database.currentDatabaseId = nil
                expect(DatabaseManager.defaultDatabase.id) == dbStruct.id

                helper.saveDatabaseLocally(dbStruct2)

                try sut.deleteCurrentDatabaseIfEmpty()

                expect(DatabaseManager.defaultDatabase.id) == dbStruct2.id
            }
        }

        describe(".save()") {
            context("with Foundation") {
                it("saves database") {
                    let dbStruct = helper.createDatabaseStruct()

                    waitUntil(timeout: .seconds(10)) { done in
                        sut.save(dbStruct, completion:  { _ in
                            done()
                        })
                    }

                    let count = Database.countWithPredicate(mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 1
                }
            }

            context("with PromiseKit") {
                it("saves database") {
                    let dbStruct = helper.createDatabaseStruct()
                    let promise: PromiseKit.Promise<Bool> = sut.save(dbStruct)

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.done { success in
                            expect(success) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }

                    let count = Database.countWithPredicate(mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 1
                }
            }

            context("with Promises") {
                it("saves database") {
                    let dbStruct = helper.createDatabaseStruct()
                    let promise: Promises.Promise<Bool> = sut.save(dbStruct)

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.then { success in
                            expect(success) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }

                    let count = Database.countWithPredicate(mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 1
                }
            }
        }

        describe(".allDatabases()") {
            beforeEach {
                // force creation
                _ = DatabaseManager.defaultDatabase
            }

            it("returns all databases") {
                expect(sut.all) == [DatabaseManager.defaultDatabase]
            }
        }

        describe(".allDatabasesTitles()") {
            beforeEach {
                // force creation
                _ = DatabaseManager.defaultDatabase
            }

            it("returns all titles") {
                expect(sut.allTitles()) == ["Default"]
            }
        }

        describe(".delete()") {
            var dbStruct: DatabaseStruct!
            beforeEach {
                dbStruct = helper.createDatabaseStruct("995d94e1-e0df-4eca-93e6-8778984bcd29")
                helper.saveDatabaseLocally(dbStruct)
            }

            context("with Foundation") {
                it("deletes database") {
                    waitUntil(timeout: .seconds(10)) { done in
                        sut.delete(dbStruct) { result in
                            expect { try result.get() }.toNot(throwError())
                            expect { try result.get() } == false
                            done()
                        }
                    }

                    let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 0
                }
            }

            context("with PromiseKit") {
                it("deletes database") {
                    let promise: PromiseKit.Promise<Bool> = sut.delete(dbStruct)

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.done { success in
                            expect(success) == false
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }

                    let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 0
                }
            }

            context("with Promises") {
                it("deletes database") {
                    let promise: Promises.Promise<Bool> = sut.delete(dbStruct)

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.then { success in
                            expect(success) == false
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }

                    let count = Database.countWithPredicate(CoreDataManager.shared.mainContext,
                                                            NSPredicate(format: "id = %@", dbStruct.id as CVarArg))
                    expect(count) == 0
                }
            }
        }
    }
}
