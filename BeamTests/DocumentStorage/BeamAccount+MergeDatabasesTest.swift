//
//  BeamAccountTest+MergeDatabases.swift
//  BeamTests
//
//  Created by Jérôme Blondon on 17/06/2022.
//

import Foundation
import XCTest
@testable import BeamCore
@testable import Beam
import Quick
import Nimble

import GRDB

class BeamAccountMergeDatabasesTest: QuickSpec, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    override func spec() {
        let basePath = "test-\(UUID())"
        guard let sut = try? BeamAccount(id: UUID(), email: "test@beamapp.co", name: "test", path: basePath) else { fail("Couldn't create test beam account")
            return
        }

        afterSuite {
            do {
                try sut.delete(self)
            } catch {
                fail(error.localizedDescription)
            }
        }

        describe("mergeDatabases") {
            var databases: [BeamDatabase] = []
            beforeEach {
                databases = []
            }
            afterEach {
                databases.forEach {
                    do { try sut.removeDatabase($0.id) } catch {}
                    do { try $0.delete(self) } catch {}
                }
            }

            context("with 1 database") {
                beforeEach {
                    do {
                        databases.append(sut.getOrCreateDefaultDatabase())
                        try databases[0].load()
                    } catch {
                        fail(error.localizedDescription)
                    }
                }

                it("does nothing") {
                    do {
                        let doc1 = try databases[0].collection?.fetchOrCreate(self, type: .note(title: "title"))
                        sut.mergeAllDatabases(initialDBs: [databases[0]])
                        let doc2 = try databases[0].collection?.fetchOrCreate(self, type: .note(title: "title"))
                        expect(doc1).to(equal(doc2))
                    }
                }

            }

            context("with 2 databases") {

                beforeEach {
                    do {
                        expect(sut.databases.count).to(equal(0))

                        databases = [
                            BeamDatabase(account: sut, id: UUID(), name: "First"),
                            BeamDatabase(account: sut, id: UUID(), name: "Second")
                        ]

                        try databases.forEach {
                            try sut.addDatabase($0)
                            try $0.load()
                        }

                        // set database1 as default
                        sut.defaultDatabaseId = databases[0].id

                        expect(sut.databases.count).to(equal(2))
                        expect(sut.getOrCreateDefaultDatabase().id).to(equal(databases[0].id))
                    } catch {
                        fail(error.localizedDescription)
                    }
                }


                it("choose the database with the most documents") {
                    do {
                        _ = try databases[0].collection?.fetchOrCreate(self, type: .note(title: "title1"))
                        _ = try databases[0].collection?.fetchOrCreate(self, type: .note(title: "title2"))

                        _ = try databases[1].collection?.fetchOrCreate(self, type: .note(title: "title3"))

                        expect(databases[0].documentsCount()).to(equal(2))
                        expect(databases[1].documentsCount()).to(equal(1))

                        sut.mergeAllDatabases(initialDBs: [databases[0]])

                        expect(databases[0].documentsCount()).to(equal(0))
                        expect(databases[1].documentsCount()).to(equal(3))
                    } catch {
                        fail(error.localizedDescription)
                    }
                }

                it("merge documents") {
                    do {
                        _ = try databases[0].collection?.fetchOrCreate(self, type: .note(title: "title1"))
                        _ = try databases[0].collection?.fetchOrCreate(self, type: .note(title: "title2"))

                        _ = try databases[1].collection?.fetchOrCreate(self, type: .note(title: "title1"))

                        expect(databases[0].documentsCount()).to(equal(2))
                        expect(databases[1].documentsCount()).to(equal(1))

                        sut.mergeAllDatabases(initialDBs: [databases[0]])

                        expect(databases[0].documentsCount()).to(equal(0))
                        expect(databases[1].documentsCount()).to(equal(2))
                    } catch {
                        fail(error.localizedDescription)
                    }
                }

                it("copy files too") {
                    do {
                        _ = try databases[0].fileDBManager?.insert(name: "test1", data: "Some test string".asData, type: "text")

                        expect(databases[0].filesCount()).to(equal(1))
                        expect(databases[1].filesCount()).to(equal(0))

                        sut.mergeAllDatabases(initialDBs: [databases[0]])

                        expect(databases[0].filesCount()).to(equal(0))
                        expect(databases[1].filesCount()).to(equal(1))

                    } catch {
                        fail(error.localizedDescription)
                    }
                }

            }

            context("with 3 databases") {

                beforeEach {
                    do {
                        expect(sut.databases.count).to(equal(0))

                        databases = [
                            BeamDatabase(account: sut, id: UUID(), name: "First"),
                            BeamDatabase(account: sut, id: UUID(), name: "Second"),
                            BeamDatabase(account: sut, id: UUID(), name: "Third")
                        ]

                        try databases.forEach {
                            try sut.addDatabase($0)
                            try $0.load()
                        }
                        // set database1 as default
                        sut.defaultDatabaseId = databases[0].id

                        expect(sut.databases.count).to(equal(3))
                        expect(sut.getOrCreateDefaultDatabase().id).to(equal(databases[0].id))
                    } catch {
                        fail(error.localizedDescription)
                    }
                }

                it("choose the database with the most documents") {
                    do {
                        _ = try databases[0].collection?.fetchOrCreate(self, type: .note(title: "title1_1"))
                        _ = try databases[0].collection?.fetchOrCreate(self, type: .note(title: "title1_2"))

                        _ = try databases[1].collection?.fetchOrCreate(self, type: .note(title: "title2_1"))

                        _ = try databases[2].collection?.fetchOrCreate(self, type: .note(title: "title3_1"))
                        _ = try databases[2].collection?.fetchOrCreate(self, type: .note(title: "title3_2"))

                        expect(databases[0].documentsCount()).to(equal(2))
                        expect(databases[1].documentsCount()).to(equal(1))
                        expect(databases[2].documentsCount()).to(equal(2))

                        sut.mergeAllDatabases(initialDBs: [databases[0]])

                        expect(databases[0].documentsCount()).to(equal(0))
                        expect(databases[1].documentsCount()).to(equal(0))
                        expect(databases[2].documentsCount()).to(equal(5))
                    } catch {
                        fail(error.localizedDescription)
                    }
                }
            }
        }
    }
}
