// swiftlint:disable file_length
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

    var hasLocalChanges: Bool {
        // We don't have a saved previous version, it's a new document
        guard let beam_api_data = beam_api_data else { return false }

        return beam_api_data != data
    }

    func delete(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext) {
        context.delete(self)
        do {
            try context.save()
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }
    }

    func database(_ context: NSManagedObjectContext = CoreDataManager.shared.mainContext) -> Database? {
        try? Database.fetchWithId(context, database_id)
    }

    func update(_ documentStruct: DocumentStruct) {
        database_id = documentStruct.databaseId
        // use mergeWithLocalChanges for `data`
        // data = documentStruct.data
        title = documentStruct.title
        document_type = documentStruct.documentType.rawValue
        created_at = documentStruct.createdAt
        updated_at = BeamDate.now
        deleted_at = documentStruct.deletedAt
        is_public = documentStruct.isPublic

        if let journalDate = documentStruct.journalDate, !journalDate.isEmpty {
            journal_day = JournalDateConverter.toInt(from: journalDate)
        }
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
