import Foundation
import CoreData
import BeamCore

class BeamToBeam2MigrationPolicy: NSEntityMigrationPolicy {
    let defaultDatabaseId = UUID()

    @objc func setDatabase() -> UUID {
        return defaultDatabaseId
    }

    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        try super.begin(mapping, with: manager)

        let defaultDatabase = NSEntityDescription.insertNewObject(forEntityName: "Database", into: manager.destinationContext)
        defaultDatabase.setValue("Default", forKey: "title")
        defaultDatabase.setValue(BeamDate.now, forKey: "created_at")
        defaultDatabase.setValue(BeamDate.now, forKey: "updated_at")
        defaultDatabase.setValue(defaultDatabaseId, forKey: "id")
    }
}
