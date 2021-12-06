//
//  Beam5ToBeam6MigrationPolicy.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 24/08/2021.
//

import Foundation
import CoreData
import BeamCore

class Beam5ToBeam6MigrationPolicy: NSEntityMigrationPolicy {
    // Had to do this manually since mapping model crash
    // This is why
    // https://stackoverflow.com/questions/46178853/why-is-my-core-data-migration-crashing-with-exc-bad-access
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        guard let journalDate = sInstance.value(forKey: "journal_date") as? String else {
            fatalError("JournalDate is nil and this should never happen")
        }
        let dInstance = NSEntityDescription.insertNewObject(forEntityName: mapping.destinationEntityName!, into: manager.destinationContext)
        let journalDay = JournalDateConverter.toInt(from: journalDate)

        dInstance.setValue(journalDay, forKey: #keyPath(Document.journal_day))
        dInstance.setValue(sInstance.value(forKey: "id"), forKey: (\Document.id)._kvcKeyPathString!)
        dInstance.setValue(sInstance.value(forKey: "data"), forKey: #keyPath(Document.data))
        dInstance.setValue(sInstance.value(forKey: "deleted_at"), forKey: #keyPath(Document.deleted_at))
        dInstance.setValue(sInstance.value(forKey: "created_at"), forKey: #keyPath(Document.created_at))
        dInstance.setValue(sInstance.value(forKey: "updated_at"), forKey: #keyPath(Document.updated_at))
        dInstance.setValue(sInstance.value(forKey: "title"), forKey: #keyPath(Document.title))
        dInstance.setValue(sInstance.value(forKey: "document_type"), forKey: #keyPath(Document.document_type))
        dInstance.setValue(sInstance.value(forKey: "version"), forKey: #keyPath(Document.version))
        dInstance.setValue(sInstance.value(forKey: "is_public"), forKey: #keyPath(Document.is_public))
        dInstance.setValue(sInstance.value(forKey: "database_id"), forKey: #keyPath(Document.database_id))

        manager.associate(sourceInstance: sInstance, withDestinationInstance: dInstance, for: mapping)
    }
}
