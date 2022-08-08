import Foundation
import CoreData
import BeamCore

class Document: NSManagedObject {
    /*
     Updating `updated_at` in `override func willSave()` raises an issue: when we receive objects from API with
     `receivedObjects` it will overwrite `updated_at` but we don't want to, as it will keep updating it
     for every remote updates we get. We want the local object to represent exactly what we fetched.

     Instead we should update `updated_at` manually when doing changes (on save).
     */

    override func awakeFromInsert() {
        super.awakeFromInsert()
        created_at = BeamDate.now
        updated_at = BeamDate.now
        id = UUID()
    }

    var uuidString: String {
        id.uuidString.lowercased()
    }

    var titleAndId: String {
        "\(title) {\(id)} v\(version)"
    }

    func database(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext) -> Database? {
        try? Database.fetchWithId(context, database_id)
    }

    // MARK: -
    // MARK: Validations
    override func validateForInsert() throws {
        try super.validateForInsert()
    }

    override func validateForDelete() throws {
        try super.validateForDelete()
    }

    override func validateForUpdate() throws {
        try super.validateForUpdate()
    }
}
