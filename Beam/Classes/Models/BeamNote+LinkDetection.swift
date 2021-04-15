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
        AppDelegate.main.data.indexer.search(matchingPhrase: title).compactMap { result -> BeamNoteReference? in
            guard let note = BeamNote.fetch(AppDelegate.main.documentManager, title: result.title),
                  let uid = result.uid.uuid,
                  let element = note.findElement(uid),
                  element.hasReferenceToNote(named: title) || element.hasLinkToNote(named: title),
                  let reftitle = element.note?.title
            else { return nil }
            return BeamNoteReference(noteTitle: reftitle, elementID: uid)
        }
    }
}
