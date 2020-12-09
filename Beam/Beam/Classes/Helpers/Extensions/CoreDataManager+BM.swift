import CoreData
import Foundation

/*
 Code taken from https://oleb.net/blog/2018/03/core-data-sqlite-backup/
 */

/// Safely copies the specified `NSPersistentStore` to a temporary file.
/// Useful for backups.
///
/// - Parameter index: The index of the persistent store in the coordinator's
///   `persistentStores` array. Passing an index that doesn't exist will trap.
///
/// - Returns: The URL of the backup file, wrapped in a TemporaryFile instance
///   for easy deletion.
extension NSPersistentStoreCoordinator {
    func backupPersistentStore(atIndex index: Int) throws -> TemporaryFile {
        // Inspiration: https://stackoverflow.com/a/22672386
        // Documentation for NSPersistentStoreCoordinate.migratePersistentStore:
        // "After invocation of this method, the specified [source] store is
        // removed from the coordinator and thus no longer a useful reference."
        // => Strategy:
        // 1. Create a new "intermediate" NSPersistentStoreCoordinator and add
        //    the original store file.
        // 2. Use this new PSC to migrate to a new file URL.
        // 3. Drop all reference to the intermediate PSC.
        precondition(persistentStores.indices.contains(index), "Index \(index) doesn't exist in persistentStores array")
        let sourceStore = persistentStores[index]
        let backupCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

        let intermediateStoreOptions = (sourceStore.options ?? [:])
            .merging([NSReadOnlyPersistentStoreOption: true],
                     uniquingKeysWith: { $1 })
        let intermediateStore = try backupCoordinator.addPersistentStore(
            ofType: sourceStore.type,
            configurationName: sourceStore.configurationName,
            at: sourceStore.url,
            options: intermediateStoreOptions
        )

        let backupStoreOptions: [AnyHashable: Any] = [
            NSReadOnlyPersistentStoreOption: true,
            // Disable write-ahead logging. Benefit: the entire store will be
            // contained in a single file. No need to handle -wal/-shm files.
            // https://developer.apple.com/library/content/qa/qa1809/_index.html
            NSSQLitePragmasOption: ["journal_mode": "DELETE"],
            // Minimize file size
            NSSQLiteManualVacuumOption: true
        ]

        // Filename format: basename-date.sqlite
        // E.g. "MyStore-20180221T200731.sqlite" (time is in UTC)
        func makeFilename() -> String {
            let basename = sourceStore.url?.deletingPathExtension().lastPathComponent ?? "store-backup"
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
            let dateString = dateFormatter.string(from: Date())
            return "\(basename)-\(dateString).sqlite"
        }

        let backupFilename = makeFilename()
        let backupFile = try TemporaryFile(creatingTempDirectoryForFilename: backupFilename)
        try backupCoordinator.migratePersistentStore(intermediateStore, to: backupFile.fileURL, options: backupStoreOptions, withType: NSSQLiteStoreType)
        return backupFile
    }
}
