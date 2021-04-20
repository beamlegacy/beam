import Foundation
import CoreData

class BeamToBeam2MigrationPolicy: NSEntityMigrationPolicy {
    let defaultDatabaseId = UUID()

    @objc func setDatabase() -> UUID {
        return defaultDatabaseId
    }

    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        try super.begin(mapping, with: manager)

        let defaultDatabase = NSEntityDescription.insertNewObject(forEntityName: "Database", into: manager.destinationContext)
        defaultDatabase.setValue("Default", forKey: "title")
        defaultDatabase.setValue(Date(), forKey: "created_at")
        defaultDatabase.setValue(Date(), forKey: "updated_at")
        defaultDatabase.setValue(defaultDatabaseId, forKey: "id")
    }
}
