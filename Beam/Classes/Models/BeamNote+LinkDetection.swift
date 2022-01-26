//
//  BeamNote+LinkDetection.swift
//  Beam
//
//  Created by Sebastien Metrot on 01/04/2021.
//

import Foundation
import BeamCore

public extension BeamNote {
    var shouldAppearInJournal: Bool {
        return !deleted && (isTodaysNote || !isEntireNoteEmpty() || !fastLinksAndReferences.isEmpty)
    }

    var mentionsCount: Int {
        Set<BeamNoteReference>(linksAndReferences(fast: true)).count
    }
    var linksAndReferences: [BeamNoteReference] {
        links + references
    }

    var fastLinksAndReferences: [BeamNoteReference] {
        links + fastReferences
    }

    var links: [BeamNoteReference] {
        (try? GRDBDatabase.shared.fetchLinks(toNote: self.id).map({ bidiLink in
            BeamNoteReference(noteID: bidiLink.sourceNoteId, elementID: bidiLink.sourceElementId)
        })) ?? []
    }

    var references: [BeamNoteReference] {
        references(verifyMatch: true)
    }

    var fastReferences: [BeamNoteReference] {
        references(verifyMatch: false)
    }

    func linksAndReferences(fast: Bool) -> [BeamNoteReference] {
        links + references(verifyMatch: !fast)
    }

    private func references(verifyMatch: Bool) -> [BeamNoteReference] {
        referencesMatching(self.title, id: self.id, verifyMatch: verifyMatch)
    }

    private func referencesMatching(_ titleToMatch: String, id idToMatch: UUID, verifyMatch: Bool) -> [BeamNoteReference] {
        GRDBDatabase.shared.search(matchingPhrase: titleToMatch, column: BeamElementRecord.Columns.text).compactMap { result -> BeamNoteReference? in
            let noteRef = BeamNoteReference(noteID: result.noteId, elementID: result.uid)
            guard result.noteId != self.id else { return nil }
            guard verifyMatch else { return noteRef }
            guard  let note = BeamNote.fetch(id: result.noteId, includeDeleted: false),
                  let element = note.findElement(result.uid),
                  element.hasReferenceToNote(named: titleToMatch)
            else { return nil }
            return noteRef
        }
    }
}

public extension BeamElement {
    var internalLinksInSelf: [BidirectionalLink] {
        guard let note = note else { return [] }
        let links = self.text.internalLinks.map { BidirectionalLink(sourceNoteId: note.id, sourceElementId: self.id, linkedNoteId: $0) }
        return links
    }

    var internalLinks: [BidirectionalLink] {
        internalLinksInSelf + children.flatMap { $0.internalLinks }
    }
}

public extension BeamElement {
    /// - Returns: true is something was actually updated
    @discardableResult
    func updateNoteNamesInInternalLinks(recursive: Bool) -> Bool {
        let res = _updateNoteNamesInInternalLinks(recursive: recursive)
        if res, let note = note, !note.cmdManager.isEmpty {
            // If the note renaming has changed anything in the currently edited note we need to reset the commandManager
            note.resetCommandManager()
            _ = note.syncedSave()
        }
        return res
    }

    private func _updateNoteNamesInInternalLinks(recursive: Bool) -> Bool {
        var res = false
        // Only update the text if it has changed
        if let resolved = text.resolvedNotesNames() {
            text = resolved
            res = true
        }

        if recursive {
            for child in children {
                res = child.updateNoteNamesInInternalLinks(recursive: recursive) || res
            }
        }

        return res
    }

}

public extension BeamNoteReference {
    var note: BeamNote? {
        BeamNote.fetch(id: noteID, includeDeleted: false)
    }

    var element: BeamElement? {
        note?.findElement(elementID)
    }
}
