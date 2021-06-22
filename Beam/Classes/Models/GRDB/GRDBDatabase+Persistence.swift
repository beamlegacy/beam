import GRDB
import BeamCore

extension GRDBDatabase {
    /// GRDB database singleton.
    static let shared = makeShared()

    /// Compute the DB filename based on the CI JobID.
    /// - Parameter dataDir: URL of the directory storing the database.
    private static func storeURLFromEnv(_ dataDir: URL) -> URL {
        var suffix = "-\(Configuration.env)"
        if let jobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
            Logger.shared.logDebug("Using Gitlab CI Job ID for GRDB sqlite file: \(jobId)", category: .search)

            suffix = "\(Configuration.env)-\(jobId)"
        }

        return dataDir.appendingPathComponent("GRDB\(suffix).sqlite")
    }

    private static func makeShared() -> GRDBDatabase {
        do {
            // Pick a folder for storing the SQLite database, as well as
            // the various temporary files created during normal database
            // operations (https://sqlite.org/tempfiles.html).
            let fileManager = FileManager()
            let dataFolder = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

            // Connect to a database on disk
            let dbURL = storeURLFromEnv(dataFolder)
            let dbPool = try DatabasePool(path: dbURL.path)

            return try GRDBDatabase(dbPool)
        } catch {
            // TODO: Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate.
            //
            // Typical reasons for an error here include:
            // * The parent directory cannot be created, or disallows writing.
            // * The database is not accessible, due to permissions or data protection when the device is locked.
            // * The device is out of space.
            // * The database could not be migrated to its latest schema version.
            // Check the error message to determine what the actual problem was.
            fatalError("Unresolved error \(error)")
        }
    }

    /// Creates an empty database (in-memory).
    static func empty() -> GRDBDatabase {
        let dbQueue = DatabaseQueue()
        return try! GRDBDatabase(dbQueue)
    }
}
