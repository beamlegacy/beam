//
//  BeamNote+LinkDetection.swift
//  Beam
//
//  Created by Sebastien Metrot on 01/04/2021.
//

import Foundation
import BeamCore

public extension BeamNote {
    var linksAndReferences: [BeamNoteReference] {
        return links + references
    }

    var links: [BeamNoteReference] {
        return (try? GRDBDatabase.shared.fetchLinks(toNote: self.id).map({ bidiLink in
            BeamNoteReference(noteID: bidiLink.sourceNoteId, elementID: bidiLink.sourceElementId)
        })) ?? []
    }

    var references: [BeamNoteReference] {
        return referencesMatching(self.title, id: self.id)
    }

    private func referencesMatching(_ titleToMatch: String, id idToMatch: UUID) -> [BeamNoteReference] {
        GRDBDatabase.shared.search(matchingPhrase: titleToMatch).compactMap { result -> BeamNoteReference? in
            guard result.noteId != self.id,
                  let note = BeamNote.fetch(AppDelegate.main.documentManager, id: result.noteId),
                  let element = note.findElement(result.uid),
                  element.hasReferenceToNote(named: titleToMatch)
            else { return nil }
            return BeamNoteReference(noteID: result.noteId, elementID: result.uid)
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
        return internalLinksInSelf + children.flatMap { $0.internalLinks }
    }
}

public extension BeamElement {
    /// - Returns: true is something was actually updated
    @discardableResult
    func updateNoteNamesInInternalLinks(recursive: Bool = false) -> Bool {
        var res = text.resolveNotesNames()

        if recursive {
            for child in children {
                res = child.updateNoteNamesInInternalLinks(recursive: recursive) || res
            }
        }

        if res, let note = note, !note.cmdManager.isEmpty {
            // If the card renaming has changed anything in the currently edited note we need to reset the commandManager
            note.resetCommandManager()
        }
        return res
    }
}

public extension BeamNoteReference {
    var note: BeamNote? {
        BeamNote.fetch(DocumentManager(), id: noteID)
    }

    var element: BeamElement? {
        return note?.findElement(elementID)
    }
}
