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
        referencesMatching(title)
    }

    private func referencesMatching(_ titleToMatch: String) -> [BeamNoteReference] {
        GRDBDatabase.shared.search(matchingPhrase: titleToMatch).compactMap { result -> BeamNoteReference? in
            guard let note = BeamNote.fetch(AppDelegate.main.documentManager, title: result.title),
                  note.id != self.id,
                  let uid = result.uid.uuid,
                  let element = note.findElement(uid),
                  element.hasReferenceToNote(named: titleToMatch) || element.hasLinkToNote(named: titleToMatch),
                  let reftitle = element.note?.title
            else { return nil }
            return BeamNoteReference(noteTitle: reftitle, elementID: uid)
        }
    }

    func updatedNotesWithLinkedReferences(afterChangingTitleFrom previousTitle: String, documentManager: DocumentManager) {
        let references = self.referencesMatching(previousTitle)
        guard !references.isEmpty else { return }
        let previousTitleLowercased = previousTitle.lowercased()
        references.forEach { reference in
            guard let referringNote = BeamNote.fetch(documentManager, title: reference.noteTitle),
                  let element = referringNote.findElement(reference.elementID),
                  element.hasLinkToNote(named: previousTitle)
            else { return }
            element.text.internalLinks
                .filter { $0.string.lowercased() == previousTitleLowercased }
                .forEach { range in
                    element.text.replaceInternalLink(range, withText: self.title)
                }
            referringNote.save(documentManager: documentManager)
        }
    }
}
