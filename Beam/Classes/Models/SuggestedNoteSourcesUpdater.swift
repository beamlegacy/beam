//
//  SuggestedNoteSourcesUpdater.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 10/08/2021.
//

import Foundation
import BeamCore
typealias UrlId = UInt64
typealias NoteId = UUID
typealias UpdateSources = [NoteId: [UrlId]]

public class SuggestedNoteSourceUpdater {
    var oldUrlGroups: [[UrlId]] = [[]]
    var oldNoteGroups: [[NoteId]] = [[]]
    private var sessionId: UUID
    private var documentManager: DocumentManager
    private let myQueue = DispatchQueue(label: "sourceSuggestionQueue")

    init(sessionId: UUID, documentManager: DocumentManager) {
        self.sessionId = sessionId
        self.documentManager = documentManager
    }

    /// Given a grouping of notes (list of lists of UUIDs), create a dictionary that helps find the integer
    /// number of the group a note is delegated to.
    ///
    /// - Parameters:
    ///   - noteGroups: list of lists of notes (each list represents one group)
    /// - Returns: A dictionary from note ID (UUID) to an integer group number
    func noteToGroup(noteGroups: [[NoteId]]) -> [NoteId: Int] {
        var noteToGroupDict: [NoteId: Int] = [:]
        for noteGroup in noteGroups.enumerated() {
            for note in noteGroup.element {
                noteToGroupDict[note] = noteGroup.offset
            }
        }
        return noteToGroupDict
    }

    /// Given a new grouping (both pages and notes seperately, both devided into groups), create instructions
    /// of sources (pages) that are to be removed and sources (pages) that are to be added as suggestions for
    /// each of the notes.
    ///
    /// - Parameters:
    ///   - urlGroups: list of lists of pages (each list represents one group)
    ///   - noteGroups: list of lists of notes (each list represents one group, corresponding to the urlGroups by location)
    /// - Returns:
    ///   - sourcesToAdd: A dictionary from noteId to a list of pageId's, representing sources that are to be added
    ///   - sourcesToRemove: A dictionary from notId to a list of pageId's, representing sources that are to be removed
    func createUpdateInstructions(urlGroups: [[UrlId]], noteGroups: [[NoteId]]) -> (sourcesToAdd: UpdateSources, sourcesToRemove: UpdateSources)? {
        var sourcesToAdd: [NoteId: [UrlId]] = [:]
        var sourcesToRemove: [NoteId: [UrlId]] = [:]

        let noteToGroupOld = noteToGroup(noteGroups: self.oldNoteGroups)
        for noteGroup in noteGroups.enumerated() {
            for noteId in noteGroup.element {
                if let noteOldGroup = noteToGroupOld[noteId] {
                    let oldSources = Set(self.oldUrlGroups[noteOldGroup])
                    let newSources = Set(urlGroups[noteGroup.offset])
                    let intersection = newSources.intersection(oldSources)
                    sourcesToAdd[noteId] = Array(newSources.subtracting(intersection))
                    sourcesToRemove[noteId] = Array(oldSources.subtracting(intersection))
                } else {
                    sourcesToAdd[noteId] = urlGroups[noteGroup.offset]
                }
            }
        }
        return (sourcesToAdd: sourcesToAdd, sourcesToRemove: sourcesToRemove)
    }

    /// Given instructions about sources that are to be added to and removed from different notes,
    /// this function performs the actual addition and removal
    ///
    /// - Parameters:
    ///   - sourcesToAdd: A dictionary from noteId to a list of pageId's, representing sources that are to be added
    ///   - sourcesToRemove: A dictionary from notId to a list of pageId's, representing sources that are to be removed
    private func addAndRemoveFromNotes(sourcesToAdd: UpdateSources, sourcesToRemove: UpdateSources) {
        let allNotes = Array(Set(sourcesToRemove.keys).union(Set(sourcesToAdd.keys)))
        for noteId in allNotes {
            if let note = BeamNote.fetch(self.documentManager, id: noteId) {
                if let addPagesToNote = sourcesToAdd[noteId] {
                    for pageId in addPagesToNote {
                        note.sources.add(urlId: pageId, type: .suggestion, sessionId: self.sessionId)
                    }
                }
                if let removePagesFromNote = sourcesToRemove[noteId] {
                    for pageId in removePagesFromNote {
                        note.sources.remove(urlId: pageId, sessionId: self.sessionId)
                    }
                }
            }
        }
    }

    /// The main function of the class, to be called when suggested note sources should be updated (i.e., when there is a new clustering result).
    ///
    /// - Parameters:
    ///   - urlGroups: list of lists of pages (each list represents one group)
    ///   - noteGroups: list of lists of notes (each list represents one group)
    public func update(urlGroups: [[UInt64]], noteGroups: [[UUID]]) {
        guard urlGroups != oldUrlGroups || noteGroups != oldNoteGroups else { return }
        myQueue.async {
            guard let (sourcesToAdd, sourcesToRemove) = self.createUpdateInstructions(urlGroups: urlGroups, noteGroups: noteGroups) else { return }

            self.addAndRemoveFromNotes(sourcesToAdd: sourcesToAdd, sourcesToRemove: sourcesToRemove)

            DispatchQueue.main.async {
                self.oldUrlGroups = urlGroups
                self.oldNoteGroups = noteGroups
            }
        }
    }
}
