import Foundation
import CoreData
import BeamCore

protocol CoreDataMigratorProtocol {
    func requiresMigration(at storeURL: URL, toVersion version: CoreDataMigrationVersion) -> Bool
    func migrateStore(at storeURL: URL, toVersion version: CoreDataMigrationVersion)
}

class CoreDataMigrator: CoreDataMigratorProtocol {
    // MARK: - Check

    func requiresMigration(at storeURL: URL, toVersion version: CoreDataMigrationVersion) -> Bool {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
            return false
        }

        return (CoreDataMigrationVersion.compatibleVersionForStoreMetadata(metadata) != version)
    }

    // MARK: - Migration
    func migrateStore(at storeURL: URL, toVersion version: CoreDataMigrationVersion) {
        Logger.shared.logDebug("Coredata migrateStore", category: .coredata)
        forceWALCheckpointingForStore(at: storeURL)
        Logger.shared.logDebug("Coredata forceWALCheckpointingForStore called", category: .coredata)

        var currentURL = storeURL
        let migrationSteps = self.migrationStepsForStore(at: storeURL, toVersion: version)

        /*
         I had *massive* issue with entityMigrationPolicyClassName sometimes being nil.
         Here are some debug if needed...
         */
        for migrationStep in migrationSteps {
            let mappingModel = migrationStep.mappingModel
            // Set policy here (I have one policy per migration, so this works)
            mappingModel.entityMappings.forEach {
                Logger.shared.logDebug("EntityMapping. sourceEntityName: \($0.sourceEntityName ?? "-"), destinationEntityName: \($0.destinationEntityName ?? "-"), entityMigrationPolicyClassName: \($0.entityMigrationPolicyClassName ?? "-")",
                                       category: .coredataDebug)
            }
        }

        for migrationStep in migrationSteps {
            let manager = NSMigrationManager(sourceModel: migrationStep.sourceModel, destinationModel: migrationStep.destinationModel)
            let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)

            do {
                try manager.migrateStore(from: currentURL,
                                         sourceType: NSSQLiteStoreType,
                                         options: nil,
                                         with: migrationStep.mappingModel,
                                         toDestinationURL: destinationURL,
                                         destinationType: NSSQLiteStoreType,
                                         destinationOptions: nil)
            } catch let error {
                fatalError("failed attempting to migrate from \(migrationStep.sourceModel) to \(migrationStep.destinationModel), error: \(error)")
            }

            if currentURL != storeURL {
                // Destroy intermediate step's store
                NSPersistentStoreCoordinator.destroyStore(at: currentURL)
            }

            currentURL = destinationURL
        }

        NSPersistentStoreCoordinator.replaceStore(at: storeURL, withStoreAt: currentURL)

        if currentURL != storeURL {
            NSPersistentStoreCoordinator.destroyStore(at: currentURL)
        }
    }

    private func migrationStepsForStore(at storeURL: URL, toVersion destinationVersion: CoreDataMigrationVersion) -> [CoreDataMigrationStep] {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let sourceVersion = CoreDataMigrationVersion.compatibleVersionForStoreMetadata(metadata) else {
                  if FileManager.default.fileExists(atPath: storeURL.path) {
                      Logger.shared.logError("Unknown store version at URL \(storeURL)", category: .coredata)
                  }

                  return []
              }

        return migrationSteps(fromSourceVersion: sourceVersion, toDestinationVersion: destinationVersion)
    }

    private func migrationSteps(fromSourceVersion sourceVersion: CoreDataMigrationVersion, toDestinationVersion destinationVersion: CoreDataMigrationVersion) -> [CoreDataMigrationStep] {
        var sourceVersion = sourceVersion
        var migrationSteps = [CoreDataMigrationStep]()

        while sourceVersion != destinationVersion, let nextVersion = sourceVersion.nextVersion() {
            let migrationStep = CoreDataMigrationStep(sourceVersion: sourceVersion, destinationVersion: nextVersion)
            migrationSteps.append(migrationStep)

            sourceVersion = nextVersion
        }

        return migrationSteps
    }

    // MARK: - WAL

    func forceWALCheckpointingForStore(at storeURL: URL) {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let currentModel = NSManagedObjectModel.compatibleModelForStoreMetadata(metadata) else {
            return
        }

        do {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)

            let options = [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
            // Note: sometimes this hangs when trying to import previous version backup to current DB
            let store = persistentStoreCoordinator.addPersistentStore(at: storeURL, options: options)

            try persistentStoreCoordinator.remove(store)
        } catch let error {
            fatalError("failed to force WAL checkpointing, error: \(error)")
        }
    }
}
