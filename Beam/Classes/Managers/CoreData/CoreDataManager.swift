import Foundation
import CoreData
import Promises
import PromiseKit
import BeamCore

/*
 We can't use ordered relationships based on CloudKit and https://stackoverflow.com/questions/56967051/how-to-set-an-ordered-relationship-with-nspersistentcloudkitcontainer

 Article for creating tests:
 https://williamboles.me/can-unit-testing-and-core-data-become-bffs/

 https://williamboles.me/progressive-core-data-migration/

 https://www.raywenderlich.com/11349416-unit-testing-core-data-in-ios

 https://medium.com/flawless-app-stories/cracking-the-tests-for-core-data-15ef893a3fee
 
 */

class CoreDataManager {
    static var shared = CoreDataManager()
    private var storeType = NSSQLiteStoreType
    private(set) var storeURL: URL?

    // Progressive migrations is based on https://williamboles.me/progressive-core-data-migration/
    let migrator: CoreDataMigratorProtocol

    lazy var backgroundContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: NSMergePolicyType.mergeByPropertyObjectTrumpMergePolicyType)

        return context
    }()

    lazy var mainContext: NSManagedObjectContext = {
        let context = self.persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true

        return context
    }()

    init(storeType: String = NSSQLiteStoreType, migrator: CoreDataMigratorProtocol = CoreDataMigrator()) {
        LoggerRecorder.shared.reset()
        self.storeType = storeType
        self.migrator = migrator
    }

    deinit {
        Logger.shared.logDebug("CoreDataManager deinit", category: .coredata)
        LoggerRecorder.shared.reset()
    }

    func setup() {
        let semaphore = DispatchSemaphore(value: 0)

        migrateAndLoadStores {
            semaphore.signal()
        }

        let semaphoreResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(10))
        if case .timedOut = semaphoreResult {
            Logger.shared.logError("Semaphore for CoreData setup timedout", category: .coredata)
            assert(false)
        }

        LoggerRecorder.shared.attach()
    }

    private func migrateAndLoadStores(completion: @escaping () -> Void) {
        migrateStoreIfNeeded {
            Logger.shared.logDebug("Coredata migrations checked", category: .coredata)
            self.loadPersistentStores(completion: completion)
        }
    }

    private func loadPersistentStores(completion: @escaping () -> Void) {
        self.persistentContainer.loadPersistentStores { description, error in
            self.storeURL = description.url

            if let fileUrl = self.storeURL {
                Logger.shared.logDebug("sqlite file: \(fileUrl)", category: .coredata)
            }

            if let error = error {
                UserAlert.showError(message: "Coredata store error", error: error)

                NSApplication.shared.terminate(nil)

                return
            }

            completion()
        }
    }

    private func migrateStoreIfNeeded(completion: @escaping () -> Void) {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            fatalError("persistentContainer was not set up properly")
        }

        if migrator.requiresMigration(at: storeURL, toVersion: CoreDataMigrationVersion.current) {
            Logger.shared.logDebug("Coredata migrations needed", category: .coredata)
            DispatchQueue.global(qos: .userInitiated).async {
                self.migrator.migrateStore(at: storeURL, toVersion: CoreDataMigrationVersion.current)

                completion()
            }
        } else {
            completion()
        }
    }

    func save() throws {
        try Self.save(mainContext)
    }

    class func save(_ context: NSManagedObjectContext) throws {
        if !context.commitEditing() {
            Logger.shared.logError("unable to commit editing before saving", category: .coredata)
        }

        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            Logger.shared.logError("unable to save: \(error.localizedDescription)", category: .coredata)
            throw error
        }
    }

    func backup(_ url: URL) throws {
        guard let storeCoordinator = mainContext.persistentStoreCoordinator else { return }
        do {
            let fileManager = FileManager()
            let backupFile = try storeCoordinator.backupPersistentStore(atIndex: 0)
            defer {
                try? backupFile.deleteDirectory()
            }

            try fileManager.copyItem(at: backupFile.fileURL, to: url)
        } catch {
            Logger.shared.logError("Can't backup: \(error)", category: .coredata)
            throw error
        }
    }

    func importBackup(_ url: URL) throws {
        guard let storeURL = storeURL else { return }
        LoggerRecorder.shared.reset()

        try persistentContainer.persistentStoreCoordinator.replacePersistentStore(at: storeURL,
                                                                                  destinationOptions: nil,
                                                                                  withPersistentStoreFrom: url,
                                                                                  sourceOptions: nil,
                                                                                  ofType: NSSQLiteStoreType)

        setup()
    }

    let persistentContainerQueue = OperationQueue()
    /// https://stackoverflow.com/questions/42733574/nspersistentcontainer-concurrency-for-saving-to-core-data
    /// Based on this link, added `completionHandler`
    func enqueue(block: @escaping (_ context: NSManagedObjectContext) -> ((Swift.Result<Bool, Error>) -> Void)?) {
        let perf = PerformanceDebug("CoreDataManager.enqueue", true, .coredata)

        // TODO: Check memory management (blockOperation create retain cycles)

        let blockOperation = BlockOperation()
        blockOperation.addExecutionBlock { [weak blockOperation, weak self] in
            guard let blockOperation = blockOperation, let self = self else { return }

            perf.debug("Executing BlockOperation")

            // In case the operationqueue was cancelled way before this started
            if blockOperation.isCancelled {
                return
            }

            let context: NSManagedObjectContext = self.persistentContainer.newBackgroundContext()
            context.performAndWait {
                let completionHandler = block(context)

                // In case the operationqueue was cancelled after the block was executed
                if blockOperation.isCancelled {
                    return
                }

                do {
                    if context.hasChanges {
                        perf.debug("willSave")
                        try context.save()
                        perf.debug("didSave")
                    }

                    completionHandler?(.success(true))
                } catch {
                    perf.debug("Error: \(error)")
                    ThirdPartyLibrariesManager.shared.nonFatalError(error: error)
                    completionHandler?(.failure(error))
                }
            }
            perf.debug("Finished Executing BlockOperation")
        }

        persistentContainerQueue.addOperation(blockOperation)
    }

    static func storeURLFromEnv() -> URL? {
        var name = "Beam-\(Configuration.env)"
        if let jobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
            name = "Beam-\(Configuration.env)-\(jobId)"
        }

        let coreDataFileName = BeamData.dataFolder(fileName: "Beam/\(name).sqlite")
        return URL(fileURLWithPath: coreDataFileName)
    }

    lazy var persistentContainer: NSPersistentContainer! = {
        let container = NSPersistentContainer(name: "Beam")

        guard let containerURL = Self.storeURLFromEnv() else { return container }

        let description = NSPersistentStoreDescription(url: storeURL ?? containerURL)

        // Supposed to enable automatic migration, but default is `true`
        // inferred mapping will be handled else where
        description.shouldInferMappingModelAutomatically = false
        description.shouldMigrateStoreAutomatically = false
        description.type = storeType

        // This is to disable iCloud sync, which could be offered
        // as an option to the user through our settings.
        description.cloudKitContainerOptions = nil

        container.persistentStoreDescriptions = [description]

        storeURL = containerURL
        storeType = description.type
        return container
    }()
}

// MARK: PromiseKit
extension CoreDataManager {
    func background() -> PromiseKit.Guarantee<NSManagedObjectContext> {
        .value(backgroundContext)
    }

    func newBackgroundContext() -> PromiseKit.Guarantee<NSManagedObjectContext> {
        .value(persistentContainer.newBackgroundContext())
    }
}

// MARK: Promises
extension CoreDataManager {
    func background() -> Promises.Promise<NSManagedObjectContext> {
        Promises.Promise(backgroundContext)
    }

    func newBackgroundContext() -> Promises.Promise<NSManagedObjectContext> {
        Promises.Promise(persistentContainer.newBackgroundContext())
    }
}

// MARK: tests
#if DEBUG
extension CoreDataManager {
    func setupWithoutMigration() {
        let semaphore = DispatchSemaphore(value: 0)

        loadPersistentStores {
            semaphore.signal()
        }

        let semaphoreResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(10))
        if case .timedOut = semaphoreResult {
            Logger.shared.logError("Semaphore for CoreData setup timedout", category: .coredata)
            assert(false)
        }
        LoggerRecorder.shared.attach()
    }
}
#endif
