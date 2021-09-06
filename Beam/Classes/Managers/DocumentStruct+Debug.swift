import Foundation
import BeamCore

extension DocumentStruct {
    public func textDescription() throws -> String {
        let beamNote = try BeamNote.instanciateNote(self,
                                                    keepInMemory: false,
                                                    decodeChildren: true)

        return beamNote.textDescription()
    }

    public func previousTextDescription() throws -> String? {
        if let beamNote = try BeamNote.instanciateNoteWithPreviousData(self, decodeChildren: true) {
            return beamNote.textDescription()
        }
        return nil
    }
}
