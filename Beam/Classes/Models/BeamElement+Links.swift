//
//  BeamElement+Links.swift
//  Beam
//
//  Created by Sebastien Metrot on 01/04/2021.
//

import Foundation
import BeamCore

public extension BeamElement {
    public func detectLinkedNotes(_ documentManager: DocumentManager, async: Bool) {
        guard let note = note else { return }
        let sourceNote = note.title

        for link in text.internalLinks where link.string != note.title {
            let linkTitle = link.string
            //            Logger.shared.logInfo("searching link \(linkTitle)", category: .document)
            let reference = BeamNoteReference(noteTitle: sourceNote, elementID: id)
            //            Logger.shared.logInfo("New link \(note.title) <-> \(linkTitle)", category: .document)

            if async {
                DispatchQueue.main.async {
                    let refnote = BeamNote.fetchOrCreate(documentManager, title: linkTitle)
                    refnote.addReference(reference)
                }
            } else {
                let refnote = BeamNote.fetchOrCreate(documentManager, title: linkTitle)
                refnote.addReference(reference)
            }
        }

        for c in children {
            c.detectLinkedNotes(documentManager, async: async)
        }
    }

    public func getDeepUnlinkedReferences(_ thisNoteTitle: String, _ allNames: [String]) -> [String: [BeamNoteReference]] {
        var references = getUnlinkedReferences(thisNoteTitle, allNames)
        for c in children {
            for res in c.getDeepUnlinkedReferences(thisNoteTitle, allNames) {
                references[res.key] = (references[res.key] ?? []) + res.value
            }
        }

        return references
    }

    public func getUnlinkedReferences(_ thisNoteTitle: String, _ allNames: [String]) -> [String: [BeamNoteReference]] {
        var references = [String: [BeamNoteReference]]()
        let existingLinks = text.internalLinks.map { range -> String in range.string }
        let string = text.text

        for noteTitle in allNames where thisNoteTitle != noteTitle {
            if !existingLinks.contains(noteTitle), string.contains(noteTitle) {
                let ref = BeamNoteReference(noteTitle: thisNoteTitle, elementID: id)
                references[noteTitle] = (references[noteTitle] ?? []) + [ref]
//                Logger.shared.logInfo("New unlink \(thisNoteTitle) --> \(note.title)", category: .document)
            }
        }

        return references
    }

    public func connectUnlinkedElement(_ thisNoteTitle: String, _ allNames: [String]) {
        let results = getUnlinkedReferences(thisNoteTitle, allNames)
        for (name, refs) in results {
            let note = BeamNote.fetchOrCreate(AppDelegate.main.data.documentManager, title: name)
            for ref in refs {
                note.addReference(ref)
            }
        }
    }
}
