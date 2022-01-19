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
    struct UpdateInstructions {
        var sourcesToAdd: UpdateSources
        var sourcesToRemove: UpdateSources
        var allSources: UpdateSources
    }

    var oldAllSources = UpdateSources()
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

    /// For a given clustering, calculate all sources to be suggested for each note at that moment
    ///
    /// - Parameters:
    ///   - urlGroups: list of lists of pages (each list represents one group)
    ///   - noteGroups: list of lists of notes (each list represents one group, corresponding to the urlGroups by location)
    ///   - activeSources: A dictionary of all notes that have active sources to a list of these active sources
    /// - Returns:
    /// A snapshot of all sources to be present as suggestions for each note
    func allSourcesPerNote(urlGroups: [[UUID]], noteGroups: [[UUID]], activeSources: [UUID: [UUID]]) -> UpdateSources {
        var allSources = [UUID: Set<UUID>]()
        for noteGroup in noteGroups.enumerated() {
            for note in noteGroup.element {
                allSources[note] = Set(urlGroups[noteGroup.offset])
                if let activeSourcesForNote = activeSources[note] {
                    for activeSource in activeSourcesForNote {
                        let urlGroupToAdd = self.groupFromPage(pageId: activeSource, urlGroups: urlGroups)
                        allSources[note] = allSources[note]?.union(Set(urlGroupToAdd))
                    }
                    allSources[note] = allSources[note]?.subtracting(activeSourcesForNote) // No need to suggest an active source for the note
                }
            }
        }
        // Take care of the case of an active source for a note that is not itself included in clustering
        let notesNotIncluded = Set(activeSources.keys).subtracting(Set(allSources.keys))
        for note in notesNotIncluded {
            if let activeSourcesForNote = activeSources[note] {
                for activeSource in activeSourcesForNote {
                    let urlGroupToAdd = self.groupFromPage(pageId: activeSource, urlGroups: urlGroups)
                    allSources[note] = (allSources[note] ?? Set([])).union(Set(urlGroupToAdd))
                }
                allSources[note] = allSources[note]?.subtracting(activeSourcesForNote)
            }
        }
        return allSources
    }

    // swiftlint:disable:next large_tuple
    func createUpdateInstructions(urlGroups: [[UUID]], noteGroups: [[UUID]], activeSources: [UUID: [UUID]]) -> UpdateInstructions? {
        var sourcesToAdd: [UUID: Set<UUID>] = [:]
        var sourcesToRemove: [UUID: Set<UUID>] = [:]
        let allSources = self.allSourcesPerNote(urlGroups: urlGroups, noteGroups: noteGroups, activeSources: activeSources)
        let allNotes = allSources.keys // A note that appeared before would "disappear" only if it is deleted by the user
        let allPages = Set(urlGroups.flatMap { $0 })
        for note in allNotes {
            let allSourcesForNote = allSources[note] ?? Set([])
            let allOldSourcesForNote = self.oldAllSources[note] ?? Set([])
            let sourcesToAddForNote = allSourcesForNote.subtracting(allOldSourcesForNote)
            let sourcesToRemoveForNote = allOldSourcesForNote.subtracting(allSourcesForNote.intersection(allPages))
            // We don't want to remove a page that has disappeared because it was removed from clustering
            if sourcesToAddForNote.count > 0 {
                sourcesToAdd[note] = sourcesToAddForNote
            }
            if sourcesToRemoveForNote.count > 0 {
                sourcesToRemove[note] = sourcesToRemoveForNote
            }
        }
        return UpdateInstructions(sourcesToAdd: sourcesToAdd, sourcesToRemove: sourcesToRemove, allSources: allSources)
    }

    /// Given a new grouping (both pages and notes seperately, both devided into groups), create instructions
    /// of sources (pages) that are to be removed and sources (pages) that are to be added as suggestions for
    /// each of the notes.
    ///
    /// - Parameters:
    ///   - urlGroups: list of lists of pages (each list represents one group)
    ///   - noteGroups: list of lists of notes (each list represents one group, corresponding to the urlGroups by location)
    ///   - activeSources: A dictionary of all notes that have active sources to a list of these active sources
    /// - Returns:
    ///   - sourcesToAdd: A dictionary from noteId to a list of pageId's, representing sources that are to be added
    ///   - sourcesToRemove: A dictionary from notId to a list of pageId's, representing sources that are to be removed
    func getSimilarityForSuggestion(suggestionPageId: UUID, noteId: UUID, activeSources: [UUID: [UUID]], similarities: [UUID: [UUID: Double]]) -> Double? {
        var finalSimilarity: Double?
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
        let allPages = Array(Set(sourcesToAdd.values.flatMap { $0 }))
        let allLongTermScores = self.LongTermUrlScoreStoreProtocol.getMany(urlIds: allPages)
        for noteId in allNotes {
            DispatchQueue.main.async {
                if let note = BeamNote.fetch(id: noteId, includeDeleted: false) {
                    if let addPagesToNote = sourcesToAdd[noteId] {
                        note.sources.refreshScores {
                            for pageId in addPagesToNote {
                                let longTermScore = allLongTermScores[pageId]
                                let frecency = try? self.frecencyFetcher.fetchOne(id: pageId, paramKey: .webVisit30d0)
                                let similarity = self.getSimilarityForSuggestion(suggestionPageId: pageId, noteId: noteId, activeSources: activeSources, similarities: similarities)
                                DispatchQueue.main.async {
                                    note.sources.add(urlId: pageId, noteId: noteId, type: .suggestion, sessionId: self.sessionId, frecency: frecency?.lastScore, similarity: similarity, longTermScore: longTermScore
                                    )
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
        myQueue.async {
            guard let updateInstructions = self.createUpdateInstructions(urlGroups: urlGroups, noteGroups: noteGroups, activeSources: activeSources) else { return }

            self.addAndRemoveFromNotes(sourcesToAdd: updateInstructions.sourcesToAdd, sourcesToRemove: updateInstructions.sourcesToRemove, activeSources: activeSources, similarities: similarities)

            DispatchQueue.main.async {
                self.oldAllSources = updateInstructions.allSources
            }
        }
    }
}
