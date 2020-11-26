import Foundation
import CoreData

/*
 We can't use ordered relationships based on CloudKit and https://stackoverflow.com/questions/56967051/how-to-set-an-ordered-relationship-with-nspersistentcloudkitcontainer

 Article for creating tests:
 https://williamboles.me/can-unit-testing-and-core-data-become-bffs/

 https://williamboles.me/progressive-core-data-migration/

 https://www.raywenderlich.com/11349416-unit-testing-core-data-in-ios

 https://medium.com/flawless-app-stories/cracking-the-tests-for-core-data-15ef893a3fee
 
 */

class CoreDataManager {
    static let shared = CoreDataManager()
    private var storeType = NSSQLiteStoreType
    private var storeURL: URL?

    init() {
    }
    deinit {
    }

    lazy var backgroundContext: NSManagedObjectContext = {
        let context = self.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: NSMergePolicyType.mergeByPropertyObjectTrumpMergePolicyType)

        return context
    }()

    lazy var mainContext: NSManagedObjectContext = {
        let context = self.persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true

        return context
    }()

    func setup(storeType: String? = nil, completion: (() -> Void)? = nil) {
        self.storeType = storeType ?? self.storeType

        loadPersistentStore {
            completion?()
        }
    }

    private func loadPersistentStore(completion: @escaping () -> Void) {
        persistentContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
            self.storeURL = storeDescription.url

            if let error = error {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate.
                // You should not use this function in a shipping application, although it may
                // be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error)")
            }

            completion()
        })
    }

    func destroyPersistentStore(completion: (() -> Void)? = nil) {
        guard let storeURL = storeURL, let persistentStoreCoordinator = mainContext.persistentStoreCoordinator else { return }

        do {
            mainContext.commitEditing()
            try mainContext.save()

            for store in persistentStoreCoordinator.persistentStores {
                try persistentStoreCoordinator.remove(store)
            }

            try persistentStoreCoordinator.destroyPersistentStore(at: storeURL,
                                                                  ofType: storeType,
                                                                  options: nil)

            NotificationCenter.default.post(name: .coredataDestroyed, object: self)
        } catch {
            fatalError("Can't run destroyPersistentStore")
            // Error Handling
        }

        completion?()
    }

    func save() throws {
        try Self.save(mainContext)
    }

    class func save(_ context: NSManagedObjectContext) throws {
        if !context.commitEditing() {
            Logger.shared.logError("unable to commit editing before saving", category: .coredata)
        }

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                Logger.shared.logError("unable to save: \(error.localizedDescription)", category: .coredata)
                throw error
            }
        }
    }

    func backup(_ url: URL) {
        guard let storeCoordinator = mainContext.persistentStoreCoordinator else { return }
        do {
            let backupFile = try storeCoordinator.backupPersistentStore(atIndex: 0)
            defer {
                // Delete temporary directory when done
                do {
                    try backupFile.deleteDirectory()
                } catch {
                    // TODO: raise error?
                    print("Error deleting temporary file: \(error)")
                }
            }

            try FileManager().copyItem(at: backupFile.fileURL, to: url)
        } catch {
            // TODO: raise error?
            print("Error backing up Core Data store: \(error)")
        }
    }

    func importBackup(_ url: URL, _ completion: (() -> Void)? = nil) {
        destroyPersistentStore {
            guard let storeURL = self.storeURL else { return }

            let fileManager = FileManager()

            do {
                if fileManager.fileExists(atPath: storeURL.path) {
                    try fileManager.removeItem(at: storeURL)
                }
                try fileManager.copyItem(at: url, to: storeURL)
            } catch {
                // TODO: raise error?
                print("Error importing backup: \(error)")
            }

            completion?()
        }
    }

    let persistentContainerQueue = OperationQueue()
    /// https://stackoverflow.com/questions/42733574/nspersistentcontainer-concurrency-for-saving-to-core-data
    /// Based on this link, added `completionHandler`
    func enqueue(block: @escaping (_ context: NSManagedObjectContext) -> ((Result<Bool, Error>) -> Void)?) {
        let perf = PerformanceDebug("CoreDataManager.enqueue", true, .coredata)

        // TODO [P1]: Check memory management (blockOperation create retain cycles)

        var blockOperation: BlockOperation?
        blockOperation = BlockOperation { [weak self] in
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
                    LibrariesManager.nonFatalError(error: error)
                    completionHandler?(.failure(error))
                }
            }
            perf.debug("Finished Executing BlockOperation")
        }

        persistentContainerQueue.addOperation(blockOperation!)
    }

    lazy var persistentContainer: NSPersistentCloudKitContainer! = {
        let container = NSPersistentCloudKitContainer(name: "Beam")
        let description = container.persistentStoreDescriptions.first
        description?.type = storeType

        return container
    }()
}
