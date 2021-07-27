import Foundation
import CoreData
import BeamCore

class Beam3ToBeam4MigrationPolicy: NSEntityMigrationPolicy {
    @objc func addJournalDate(forData: Data) -> String? {
        let decoder = JSONDecoder()
        let note = try? decoder.decode(BeamNote.self, from: forData)
        return note?.type.journalDateString
    }
}
