//
//  BeamNote+LinkDetection.swift
//  Beam
//
//  Created by Sebastien Metrot on 01/04/2021.
//

import Foundation
import BeamCore

public extension BeamNote {
    var references: [BeamNoteReference] {
        let links = try? GRDBDatabase.shared.fetchLinks(toNote: self.id).map({ bidiLink in
            BeamNoteReference(noteID: bidiLink.sourceNoteId, elementID: bidiLink.sourceElementId)
        })
        return referencesMatching(self.title, id: self.id) + (links ?? [])

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
    var internalLinks: [BidirectionalLink] {
        guard let note = note else { return [] }
        let links = self.text.internalLinks.map { BidirectionalLink(sourceNoteId: note.id, sourceElementId: self.id, linkedNoteId: $0) }
        return links + children.flatMap { $0.internalLinks }
    }
}
