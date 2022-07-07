//
//  BeamDocumentCollection+Notifications.swift
//  Beam
//
//  Created by Sebastien Metrot on 10/05/2022.
//

import Foundation
import Combine
import BeamCore

// MARK: - notification

public extension BeamDocumentCollection {
    /// This publisher is triggered anytime we store a document in the DB.
    static let documentSaved = PassthroughSubject<BeamDocument, Never>()
    /// This publisher is triggered anytime we are completely removing a note from the DB.
    static let documentDeleted = PassthroughSubject<BeamDocument, Never>()

    private static var notificationLock = RWLock()
    private static var waitingSavedNotifications = [UUID: BeamDocument]()
    private static var waitingDeletedNotifications = Set<BeamDocument>()
    private static var notificationStatus = 1

    internal static func notifyDocumentSaved(_ document: BeamDocument) {
        if notificationEnabled {
            documentSaved.send(document)
        } else {
            notificationLock.write {
                waitingSavedNotifications[document.id] = document
            }
        }
    }

    internal static func notifyDocumentDeleted(_ source: BeamDocumentSource, _ document: BeamDocument) {
        if notificationEnabled {
            documentDeleted.send(document)
        } else {
            _ = notificationLock.write {
                waitingDeletedNotifications.insert(document)
            }
        }
    }

    static var notificationEnabled: Bool {
        notificationLock.read {
            notificationStatus > 0
        }
    }
    static func disableNotifications() {
        notificationLock.write {
            notificationStatus -= 1
        }
    }
    static func enableNotifications() {
        notificationLock.write {
            notificationStatus += 1
            assert(notificationStatus <= 1)
        }
        purgeNotifications()
    }

    private static func purgeNotifications() {
        guard notificationEnabled else { return }
        notificationLock.write {
            for saved in self.waitingSavedNotifications.values {
                Self.documentSaved.send(saved)
            }
            for deleted in self.waitingDeletedNotifications {
                Self.documentDeleted.send(deleted)
            }

            self.waitingSavedNotifications.removeAll()
            self.waitingDeletedNotifications.removeAll()
        }
    }
}
