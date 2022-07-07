//
//  GRDBStore.swift
//  BeamCore
//
//  Created by Sebastien Metrot on 17/05/2022.
//

import Foundation
import GRDB
import BeamCore

public class GRDBStore {
    let writer: DatabaseWriter
    var reader: DatabaseReader { writer }
    private var migrator = DatabaseMigrator()
    var instances = Set<String>()

    static func empty() -> GRDBStore {
        return GRDBStore(writer: DatabaseQueue())
    }

    public init(writer: DatabaseWriter) {
        self.writer = writer
        lock.initialize(to: pthread_rwlock_t())
        pthread_rwlock_init(lock, nil)
    }

    deinit {
        assert(isEmpty)
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    public enum MigrationStatus {
        /// migrations are `complete` if all migrations have been applied to the DB
        case complete
        /// migrations are `incomplete` is the migrator contains migrations that haven't been applied to the DB yet
        case incomplete
        /// migrations are `superseeded` if the DB contains migrations that the migrator doesn't know about: it's a database from the future!
        case superseeded
    }

    public func setupMigration<T: GRDBHandler>(_ handler: T) throws {
        let typename = String(describing: handler)
        guard !instances.contains(typename) else { return }
        try handler.prepareMigration(migrator: &migrator)
        instances.insert(typename)
    }

    public func checkCurrentMigrationStatus() throws -> MigrationStatus {
        try read { db in
            if try self.migrator.hasBeenSuperseded(db) {
                return .superseeded
            } else if try self.migrator.hasCompletedMigrations(db) {
                return .complete
            }
            return .incomplete
        }
    }

    public func migrate(upTo: String? = nil) throws {
        if let upTo = upTo {
            try migrator.migrate(writer, upTo: upTo)
        } else {
            try migrator.migrate(writer)
        }
    }

    // MARK: Transactions:
    /// Access to writing to the GRDB Database. This is important as it enables recursive calls to write and read transactions, which GRDB doesn't permits
    /// execute a block of code inside a transaction that groups accesses to the database
    public func run<T>(_ transaction: @escaping () throws -> T) throws -> T {
        let threadId = pthread_self()
        guard getDb(forThread: threadId) != nil else {
            return try writer.write { db in
                try self.safeCall(db: db, threadId: threadId) { try transaction() }
            }
        }
        return try transaction()
    }

    // MARK: Private DB Access
    // MARK: Transactions:
    /// Access to writing to the GRDB Database. This is important as it enables recursive calls to write and read transactions, which GRDB doesn't permits

    private var dbs: [pthread_t: GRDB.Database] = [:]
    private var lock = UnsafeMutablePointer<pthread_rwlock_t>.allocate(capacity: 1)

    private func setDb(_ db: GRDB.Database?, forThread thread: pthread_t) {
        pthread_rwlock_wrlock(lock)
        if let db = db {
            self.dbs[thread] = db
        } else {
            self.dbs.removeValue(forKey: thread)
        }
        pthread_rwlock_unlock(lock)
    }

    private func getDb(forThread thread: pthread_t) -> GRDB.Database? {
        pthread_rwlock_rdlock(lock)
        let db = self.dbs[thread]
        pthread_rwlock_unlock(lock)
        return db
    }

    /// execute a transaction that writes in the database
    internal func write<T>(_ updates: @escaping (GRDB.Database) throws -> T) throws -> T {
        let threadId = pthread_self()
        guard let db = getDb(forThread: threadId) else {
            return try writer.write { db in
                try self.safeCall(db: db, threadId: threadId) { try updates(db) }
            }
        }
        return try updates(db)
    }

    /// execute a transaction that reads in the database
    internal func read<T>(_ value: @escaping (GRDB.Database) throws -> T) throws -> T {
        let threadId = pthread_self()
        guard let db = getDb(forThread: threadId) else {
            return try reader.read { db in
                try self.safeCall(db: db, threadId: threadId) { try value(db) }
            }
        }
        return try value(db)
    }

    /// execute a transaction that asynchronously reads in the database
    internal func asyncRead(_ value: @escaping (Result<GRDB.Database, Error>) -> Void) {
        reader.asyncRead { result in
            let threadId = pthread_self()
            guard let db = try? result.get() else { return }
            self.setDb(db, forThread: threadId)
            value(result)

            self.setDb(nil, forThread: threadId)
        }
    }

    private func safeCall<T>(db: GRDB.Database, threadId: pthread_t, _ block: @escaping () throws -> T) throws -> T {
        assert(getDb(forThread: threadId) == nil)
        setDb(db, forThread: threadId)

        let cleanup = {
            self.setDb(nil, forThread: threadId)
            assert(self.getDb(forThread: threadId) == nil)
        }

        do {
            let r = try block()
            cleanup()
            return r
        } catch {
            cleanup()
            throw error
        }

    }

    internal func track<Value>(filters: @escaping (GRDB.Database) throws -> Value, scheduling scheduler: ValueObservationScheduler) -> DatabasePublishers.Value<Value> {
        ValueObservation.tracking { db in
            try filters(db)
        }.publisher(in: reader, scheduling: scheduler)
    }

    public func erase() throws {
        try writer.erase()
    }

    internal var isEmpty: Bool {
        dbs.isEmpty
    }

    public func isFTSEnabled(on table: String) -> Bool {
        return (try? read { db in
            (try? db.execute(sql: "SELECT \(table) FROM \(table)")) != nil
        }) ?? false
    }

    public func checkAndRepairIntegrity() {
        try? write { db in
            let tables = try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master WHERE type='table'
                """)

            typealias DBError = GRDB.DatabaseError

            for table in tables {
                do {
                    if self.isFTSEnabled(on: table) {
                        try db.execute(sql: "INSERT INTO \(table)(\(table)) VALUES('integrity-check')")
                    }
                    try db.execute(sql: "PRAGMA main.quick_check(\(table))")
                } catch {
                    Logger.shared.logWarning("Integrity issue detected on '\(table)' table", category: .database)
                    EventsTracker.sendManualReport(forError: error)
                    if let dbError = error as? GRDB.DatabaseError,
                       [DBError.SQLITE_CORRUPT, DBError.SQLITE_CORRUPT_VTAB, DBError.SQLITE_CORRUPT_INDEX].map({ $0.primaryResultCode }).contains(dbError.resultCode) {
                        // check if FTS is enabled by requesting the column with the same name as the table in the table
                        if (try? db.execute(sql: "SELECT \(table) FROM \(table)")) != nil {
                            Logger.shared.logWarning("Rebuilding '\(table)' table", category: .database)
                            do {
                                try db.execute(sql: "INSERT INTO \(table)(\(table)) VALUES('rebuild')")
                            } catch {
                                EventsTracker.sendManualReport(forError: error)
                            }
                        }
                    }
                }
            }
        }
    }
}
