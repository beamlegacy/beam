//
//  GRDBHandler.swift
//  BeamCore
//
//  Created by Sebastien Metrot on 12/05/2022.
//

import Foundation
import Combine
import GRDB
import BeamCore

public enum GRDBHandlerError: Error {
    case databasePathNotFound

    case migrationFailed
}

open class GRDBHandler {
    private let store: GRDBStore
    private var writer: DatabaseWriter { store.writer }
    private var reader: DatabaseReader { store.reader }

    var tableNames: [String] { [] }

    public init(store: GRDBStore) throws {
        self.store = store
        try store.setupMigration(self)
    }

    // MARK: Migration
    open func prepareMigration(migrator: inout DatabaseMigrator) throws {
    }

    public func checkCurrentMigrationStatus() throws -> GRDBStore.MigrationStatus {
        try store.checkCurrentMigrationStatus()
    }

    // MARK: Transactions:
    /// Access to writing to the GRDB Database. This is important as it enables recursive calls to write and read transactions, which GRDB doesn't permits
    /// execute a block of code inside a transaction that groups accesses to the database
    public func run<T>(_ transaction: @escaping () throws -> T) throws -> T {
        try store.run(transaction)
    }

    // MARK: Private DB Access
    // MARK: Transactions:
    /// Access to writing to the GRDB Database. This is important as it enables recursive calls to write and read transactions, which GRDB doesn't permits

    /// execute a transaction that writes in the database
    internal func write<T>(_ updates: @escaping (GRDB.Database) throws -> T) throws -> T {
        try store.write(updates)
    }

    /// execute a transaction that writes in the database
    internal func read<T>(_ value: @escaping (GRDB.Database) throws -> T) throws -> T {
        try store.read(value)
    }

    internal func asyncRead(_ value: @escaping (Result<GRDB.Database, Error>) -> Void) {
        store.asyncRead(value)
    }

    internal func track<Value>(filters: @escaping (GRDB.Database) throws -> Value, scheduling scheduler: ValueObservationScheduler) -> DatabasePublishers.Value<Value> {
        store.track(filters: filters, scheduling: scheduler)
    }

    // MARK: Debugging
    func isFTSEnabled(on table: String) -> Bool {
        store.isFTSEnabled(on: table)
    }

    func clear() throws {
        for table in tableNames {
            do {
                try write { db in
                    try db.execute(sql: "DELETE FROM \(table)")
                }
            } catch {
                Logger.shared.logError("Error when clearing the table \(table) from manager \(Self.self): \(error)", category: .database)
            }
        }
    }
}
