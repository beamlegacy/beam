import Foundation
import CoreData
import BeamCore

class Beam3ToBeam4MigrationPolicy: NSEntityMigrationPolicy {
    @objc func addJournalDate(forData: Data) -> String? {
        let decoder = BeamJSONDecoder()
        decoder.userInfo[BeamElement.recursiveCoding] = false
        guard let note = try? decoder.decode(BeamNote.self, from: forData) else { return nil }

        let value = note.type.journalDateString ?? BeamNoteType.iso8601ForDate(note.creationDate)
        return value
    }
}
