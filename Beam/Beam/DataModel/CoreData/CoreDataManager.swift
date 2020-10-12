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

        } catch {
            fatalError("Can't run destroyPersistentStore")
            // Error Handling
        }

        completion?()
    }

    func save() {
        let context = mainContext

        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if context.hasChanges {
            do {
                try context.save()
            } catch {
            }
        }
    }

    lazy var persistentContainer: NSPersistentCloudKitContainer! = {
        let container = NSPersistentCloudKitContainer(name: "Beam")
        let description = container.persistentStoreDescriptions.first
        description?.type = storeType

        return container
    }()
}
