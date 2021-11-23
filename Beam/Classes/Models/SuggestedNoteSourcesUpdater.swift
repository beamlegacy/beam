//
//  SuggestedNoteSourcesUpdater.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 10/08/2021.
//

import Foundation
import BeamCore
typealias UpdateSources = [UUID: Set<UUID>]

public class SuggestedNoteSourceUpdater {
    var oldUrlGroups: [[UUID]] = [[]]
    var oldNoteGroups: [[UUID]] = [[]]
    var oldActiveSources = [UUID: [UUID]]() // Per note, all of its active sources (if any)
    // TODO: When uploading active sources from database, make sure to initialise  the updater with it
    private var sessionId: UUID
    private let myQueue = DispatchQueue(label: "sourceSuggestionQueue")
    let frecencyFetcher = GRDBUrlFrecencyStorage()
    let LongTermUrlScoreStoreProtocol = LongTermUrlScoreStore.shared

    init(sessionId: UUID) {
        self.sessionId = sessionId
    }

    /// Given a grouping of notes (list of lists of UUIDs), create a dictionary that helps find the integer
    /// number of the group a note is delegated to.
    ///
    /// - Parameters:
    ///   - noteGroups: list of lists of notes (each list represents one group)
    /// - Returns: A dictionary from note ID (UUID) to an integer group number
    func noteToGroup(noteGroups: [[UUID]]) -> [UUID: Int] {
        var noteToGroupDict: [UUID: Int] = [:]
        for noteGroup in noteGroups.enumerated() {
            for note in noteGroup.element {
                noteToGroupDict[note] = noteGroup.offset
            }
        }
        return noteToGroupDict
    }

    /// For a given page, this function returns the group of pages (only) this page is a part of, if the page appears in the groupins at all.
    ///
    /// - Parameters:
    ///   - urlGroups: list of lists of pages (each list represents one group)
    ///   - pageId: The page to be found
    /// - Returns:
    ///   - A list of pageId's (UUID), including the entire group of the page (including itself), if the page exists in the gourping
    func groupFromPage(pageId: UUID, urlGroups: [[UUID]]) -> [UUID] {
        for group in urlGroups {
            if group.contains(pageId) { return group }
        }
        return []
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
    func createUpdateInstructions(urlGroups: [[UUID]], noteGroups: [[UUID]], activeSources: [UUID: [UUID]]) -> (sourcesToAdd: UpdateSources, sourcesToRemove: UpdateSources)? {
        var sourcesToAdd: [UUID: Set<UUID>] = [:]
        var sourcesToRemove: [UUID: Set<UUID>] = [:]

        // Adding and removing notes do to them going into or out of a common group with the note itself
        let noteToGroupOld = noteToGroup(noteGroups: self.oldNoteGroups)
        for noteGroup in noteGroups.enumerated() {
            for noteId in noteGroup.element {
                if let noteOldGroup = noteToGroupOld[noteId] {
                    let oldSources = Set(self.oldUrlGroups[noteOldGroup])
                    let newSources = Set(urlGroups[noteGroup.offset])
                    sourcesToAdd[noteId] = newSources.subtracting(oldSources)
                    sourcesToRemove[noteId] = oldSources.subtracting(newSources)
                } else {
                    sourcesToAdd[noteId] = Set(urlGroups[noteGroup.offset])
                }
            }
        }

        // Adding and removing sources due to active sources
        let noteToGroupNew = noteToGroup(noteGroups: noteGroups)
        for noteId in activeSources.keys {
            for pageId in activeSources[noteId] ?? [] {
                let newGroup = self.groupFromPage(pageId: pageId, urlGroups: urlGroups)
                let oldGroup = self.groupFromPage(pageId: pageId, urlGroups: self.oldUrlGroups)
                var sourcesToAddForNote = Set([UUID]())
                if let oldActiveSourcesForNote = self.oldActiveSources[noteId],
                   oldActiveSourcesForNote.contains(pageId) {
                    sourcesToAddForNote = Set(newGroup).subtracting(Set(oldGroup))
                } else {
                    sourcesToAddForNote = Set(newGroup).subtracting(Set(activeSources[noteId] ?? []))
                    // If it is a new acrive source for the note, add all of the group
                }
                var doNotRemove = Set(self.oldUrlGroups.joined()).subtracting(Set(urlGroups.joined())) // Pages that appeared before and no longer appear should not be removed, as they were deleted
                if let groupIndex = noteToGroupNew[noteId] {
                    doNotRemove = doNotRemove.union(Set(urlGroups[groupIndex]))
                    //Do not remove pages - despite splitting with an active source, they're in the same group as the note itself
                }
                var sourcesToRemoveForNote = Set(oldGroup).subtracting(Set(newGroup))
                sourcesToRemoveForNote = sourcesToRemoveForNote.subtracting(Set(doNotRemove))
                sourcesToAdd[noteId] = Set(sourcesToAdd[noteId] ?? []).union(sourcesToAddForNote)
                sourcesToRemove[noteId] = Set(sourcesToRemove[noteId] ?? []).union(sourcesToRemoveForNote)
            }
        }

        // Not removing pages which, despite seperating with the note or with an active source, are still with an(other) active source in the same group
        for noteId in sourcesToRemove.keys {
            var pagesInGroupWithActive = [UUID]()
            for activeSourceId in activeSources[noteId] ?? [] {
                pagesInGroupWithActive += groupFromPage(pageId: activeSourceId, urlGroups: urlGroups)
            }
            sourcesToRemove[noteId] = Set(sourcesToRemove[noteId] ?? []).subtracting(Set(pagesInGroupWithActive))
        }
        return (sourcesToAdd: sourcesToAdd, sourcesToRemove: sourcesToRemove)
    }

    
    func getSimilarityForSuggestion(suggestionPageId: UUID, noteId: UUID, activeSources: [UUID: [UUID]], similarities: [UUID: [UUID: Double]]) -> Double? {
        var finalSimilarity: Double? = nil
        finalSimilarity = similarities[noteId]?[suggestionPageId]
        for pageId in (activeSources[noteId] ?? [UUID]()) {
            if let similarity = similarities[pageId]?[suggestionPageId] {
                finalSimilarity = max(finalSimilarity ?? similarity, similarity)
            }
        }
        return finalSimilarity
    }
    /// Given instructions about sources that are to be added to and removed from different notes,
    /// this function performs the actual addition and removal
    ///
    /// - Parameters:
    ///   - sourcesToAdd: A dictionary from noteId to a list of pageId's, representing sources that are to be added
    ///   - sourcesToRemove: A dictionary from notId to a list of pageId's, representing sources that are to be removed
    private func addAndRemoveFromNotes(sourcesToAdd: UpdateSources, sourcesToRemove: UpdateSources, activeSources: [UUID: [UUID]], similarities: [UUID: [UUID: Double]]) {
        let allNotes = Array(Set(sourcesToRemove.keys).union(Set(sourcesToAdd.keys)))
        for noteId in allNotes {
            DispatchQueue.main.async {
                if let note = BeamNote.fetch(id: noteId) {
                    if let addPagesToNote = sourcesToAdd[noteId] {
                        note.sources.refreshScores {
                            for pageId in addPagesToNote {
                                let longTermScore = self.LongTermUrlScoreStoreProtocol.getMany(urlIds: [pageId])
                                let frecency = try? self.frecencyFetcher.fetchOne(id: pageId, paramKey: .webVisit30d0)
                                let similarity = self.getSimilarityForSuggestion(suggestionPageId: pageId, noteId: noteId, activeSources: activeSources, similarities: similarities)
                                DispatchQueue.main.async {
                                    note.sources.add(urlId: pageId, noteId: noteId, type: .suggestion, sessionId: self.sessionId, frecency: frecency?.lastScore, similarity: similarity, longTermScore: longTermScore[0])
                                }
                            }
                        }
                    }
                    if let removePagesFromNote = sourcesToRemove[noteId] {
                        for pageId in removePagesFromNote {
                            note.sources.remove(urlId: pageId, noteId: noteId, sessionId: self.sessionId)
                        }
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
    public func update(urlGroups: [[UUID]], noteGroups: [[UUID]], activeSources: [UUID: [UUID]] = [UUID: [UUID]](), similarities: [UUID: [UUID: Double]]) {
        guard urlGroups != oldUrlGroups || noteGroups != oldNoteGroups else { return }
        myQueue.async {
            guard let (sourcesToAdd, sourcesToRemove) = self.createUpdateInstructions(urlGroups: urlGroups, noteGroups: noteGroups, activeSources: activeSources) else { return }

            self.addAndRemoveFromNotes(sourcesToAdd: sourcesToAdd, sourcesToRemove: sourcesToRemove, activeSources: activeSources, similarities: similarities)

            DispatchQueue.main.async {
                self.oldUrlGroups = urlGroups
                self.oldNoteGroups = noteGroups
                self.oldActiveSources = activeSources
            }
        }
    }
}
