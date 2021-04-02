//
//  BeamNote+LinkDetection.swift
//  Beam
//
//  Created by Sebastien Metrot on 01/04/2021.
//

import Foundation
import BeamCore

public extension BeamNote {
    static func requestLinkDetection(for noteTitled: String? = nil) {
        guard !linkDetectionRunning else { return }
        linkDetectionRunning = true

        linkDetectionQueue.async {
            detectLinks(for: noteTitled)
            DispatchQueue.main.async {
                linkDetectionRunning = false
            }
        }
    }

    static func detectLinks(in noteTitle: String, to allNotes: [String], with documentManager: DocumentManager) {
        guard let doc = documentManager.loadDocByTitleInBg(title: noteTitle.lowercased()) else {
            return
        }

        do {
            let note = try BeamNote.instanciateNote(documentManager, doc, keepInMemory: false)

            // Detect Linked Notes
            note.detectLinkedNotes(documentManager, async: true)

            // remove broken linked references
            let brokenLinks = note.getBrokenLinkedReferences(documentManager, allNotes)

            // remove broken unlinked references
            let brokenRefs = note.getBrokenUnlinkedReferences(documentManager, allNotes)

            // Detect UnLinked Notes
            let unlinks = note.getDeepUnlinkedReferences(noteTitle, allNotes)
            DispatchQueue.main.async {
                let note = BeamNote.fetch(documentManager, title: noteTitle)

                for brokenLink in brokenLinks {
                    note?.removeReference(brokenLink)
                }

                for brokenRef in brokenRefs {
                    note?.removeReference(brokenRef)
                }

                for (name, refs) in unlinks {
                    let referencedNote = BeamNote.fetch(documentManager, title: name)
                    for ref in refs {
                        referencedNote?.addReference(ref)
                    }
                }
            }
        } catch {
            Logger.shared.logError("LinkDetection: Unable to decode note \(doc.title)", category: .document)
        }
    }

    static func detectLinks(for noteTitled: String? = nil) {
        let documentManager = DocumentManager()
        let allNotes = documentManager.allDocumentsTitles()
        let allTitles = noteTitled == nil ? allNotes : [noteTitled!]
        Logger.shared.logInfo("Detect links for \(allTitles.count) notes", category: .document)

        for title in allNotes {
            detectLinks(in: title, to: allTitles, with: documentManager)
        }
    }

    func getBrokenLinkedReferences(_ documentManager: DocumentManager, _ allNotes: [String]) -> [BeamNoteReference] {
        var broken = [BeamNoteReference]()
        var notes = [String: BeamNote]()
        for link in references {
            guard let note: BeamNote = {
                notes[link.noteTitle] ?? {
                    guard let doc = documentManager.loadDocumentByTitle(title: link.noteTitle.lowercased()) else {
                        return nil
                    }

                    do {
                        let note = try Self.instanciateNote(documentManager, doc, keepInMemory: false)
                        notes[note.title] = note
                        return note
                    } catch {
                        Logger.shared.logError("LinkReference verification: Unable to decode note \(doc.title)", category: .document)
                    }
                    return nil
                }()
            }() else {
                continue
            }

            guard let element = note.findElement(link.elementID),
                  element.hasLinkToNote(named: title)
            else { broken.append(link); continue }
        }

        return broken
    }

    func getBrokenUnlinkedReferences(_ documentManager: DocumentManager, _ allNotes: [String]) -> [BeamNoteReference] {
        var broken = [BeamNoteReference]()
        var notes = [String: BeamNote]()
        for ref in references {
            guard let note: BeamNote = {
                notes[ref.noteTitle] ?? {
                    guard let doc = documentManager.loadDocumentByTitle(title: ref.noteTitle.lowercased()) else {
                        return nil
                    }

                    do {
                        let note = try Self.instanciateNote(documentManager, doc, keepInMemory: false)
                        notes[note.title] = note
                        return note
                    } catch {
                        Logger.shared.logError("UnlinkReference verification: Unable to decode note \(doc.title)", category: .document)
                    }
                    return nil
                }()
            }() else {
                continue
            }

            guard let element = note.findElement(ref.elementID),
                  let refs = element.getUnlinkedReferences(note.title, allNotes)[title],
                  refs.contains(ref)
            else {
                broken.append(ref)
                continue
            }
        }

        return broken
    }
}
