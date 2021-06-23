//
//  CoreDataContextObserver.swift
//  Beam
//
//  Created by Remi Santos on 19/05/2021.
//

import Foundation
import Combine

/**
 * Helper that lets a client observe the core data context changes
 * Use with moderation, only top level classes should use it to propagate events to their children
 */
class CoreDataContextObserver {
    typealias DocumentIds = Set<UUID>

    static var shared = CoreDataContextObserver()

    enum ChangeType {
        case anyDocumentChange
        case insertedDocuments
        case deletedDocuments
    }

    func publisher(for type: ChangeType) -> AnyPublisher<DocumentIds?, Never> {
        switch type {
        case .insertedDocuments:
            return insertedDocumentsSubject.eraseToAnyPublisher()
        case .deletedDocuments:
            return deletedDocumentsSubject.eraseToAnyPublisher()
        case .anyDocumentChange:
            return anyDocumentChangeSubject.eraseToAnyPublisher()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private let anyDocumentChangeSubject = PassthroughSubject<DocumentIds?, Never>()
    private let deletedDocumentsSubject = PassthroughSubject<DocumentIds?, Never>()
    private let insertedDocumentsSubject = PassthroughSubject<DocumentIds?, Never>()

    init() {
        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextObjectsDidChange)
            .sink { [weak self] notification in
                guard !Thread.isMainThread else { return }
                guard let self = self else { return }
                var hasAnyDocumentChange = false
                var finalDocuments = DocumentIds()
                if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>,
                   let deletedDocuments = self.documentsInObjectSet(deletedObjects),
                   !deletedDocuments.isEmpty {
                    hasAnyDocumentChange = true
                    finalDocuments = Set(deletedDocuments.map { $0.id })
                    self.deletedDocumentsSubject.send(finalDocuments)
                }
                if let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<Document>,
                   let insertedDocuments = self.documentsInObjectSet(insertedObjects),
                   !insertedDocuments.isEmpty {
                    hasAnyDocumentChange = true
                    finalDocuments = Set(insertedDocuments.map { $0.id })
                    self.insertedDocumentsSubject.send(finalDocuments)
                }
                if hasAnyDocumentChange {
                    self.anyDocumentChangeSubject.send(finalDocuments)
                }
            }
            .store(in: &cancellables)
    }

    private func documentsInObjectSet(_ set: Set<NSManagedObject>) -> Set<Document>? {
        return set.filter { $0 is Document } as? Set<Document>
    }
}
