import Foundation
import CoreData
import SwiftUI
import Combine

extension NoteList {
    final class ViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
        private let managedObjectContext: NSManagedObjectContext
        private let notesController: NSFetchedResultsController<Note>

        init(managedObjectContext: NSManagedObjectContext) {
            self.managedObjectContext = managedObjectContext
            let sortDescriptors = [NSSortDescriptor(keyPath: \Note.title, ascending: true)]
            notesController = Note.resultsController(context: managedObjectContext, sortDescriptors: sortDescriptors)
            super.init()
            notesController.delegate = self
            try? notesController.performFetch()
            observeChangeNotification()
        }

        func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
            objectWillChange.send()
        }

        var notes: [Note] {
            return notesController.fetchedObjects ?? []
        }

        private var cancellables = [AnyCancellable]()

        private func observeChangeNotification() {
            let cancellable = NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange,
                                                                   object: managedObjectContext)
                .compactMap({ ManagedObjectContextChanges<Note>(notification: $0) })
                .sink { changes in
                    print(changes)
                }

            cancellables.append(cancellable)
        }
    }
}

extension Note {
    static func resultsController(context: NSManagedObjectContext, sortDescriptors: [NSSortDescriptor] = []) -> NSFetchedResultsController<Note> {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = sortDescriptors.isEmpty ? nil : sortDescriptors
        return NSFetchedResultsController(fetchRequest: request,
                                          managedObjectContext: context,
                                          sectionNameKeyPath: nil,
                                          cacheName: nil)
    }
}

struct ManagedObjectContextChanges<T: NSManagedObject> {
    let inserted: Set<T>
    let deleted: Set<T>
    let updated: Set<T>

    init?(notification: Notification) {
        let unpack: (String) -> Set<T> = { key in
            let managedObjects = (notification.userInfo?[key] as? Set<NSManagedObject>) ?? []
            return Set(managedObjects.compactMap({ $0 as? T }))
        }
        deleted = unpack(NSDeletedObjectsKey)
        inserted = unpack(NSInsertedObjectsKey)
        updated = unpack(NSUpdatedObjectsKey).union(unpack(NSRefreshedObjectsKey))
        if deleted.isEmpty, inserted.isEmpty, updated.isEmpty {
            return nil
        }
    }
}
