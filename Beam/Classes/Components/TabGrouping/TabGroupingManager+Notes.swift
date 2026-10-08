//
//  TabGroupingManager+Notes.swift
//  Beam
//
//  Created by Remi Santos on 26/07/2022.
//

import Foundation
import BeamCore

// MARK: - Group Shared & in Note
extension TabGroupingManager: BeamDocumentSource {
    static var sourceId: String { "TabGroupingManager" }

    enum TabGroupSharingError: Error {
        case couldntCreateNote
        case couldntSaveNote
    }

    /// checks if group is already shared and in a tab group note.
    func fetchTabGroupNote(for group: TabGroup) -> (note: BeamNote, group: TabGroup)? {
        guard storeManager?.fetch(byIds: [group.id]).first != nil else { return nil }
        var note: BeamNote?
        if group.isLocked, let groupNote = BeamNote.fetch(tabGroupId: group.id) {
            // group already has a shared note.
            return (groupNote, group)
        }

        var groupUsed = group
        // Check if this group already have a shared copy.
            storeManager?.fetch(copiesOfGroup: group.id).forEach { childGroup in
            guard note == nil else { return }
            note = BeamNote.fetch(tabGroupId: childGroup.id)
            if note != nil {
                groupUsed = TabGroupingStoreManager.convertBeamObjectToGroup(childGroup)
            }
        }
        guard let note = note else { return nil }
        return (note, groupUsed)
    }

    @MainActor
    func fetchOrCreateTabGroupNote(for group: TabGroup) async throws -> (note: BeamNote, group: TabGroup) {
        let result = fetchTabGroupNote(for: group)
        var note = result?.note
        var groupUsed = result?.group ?? group
        if result == nil {
            let frozenGroup = await self.copyForSharing(group)
            groupUsed = frozenGroup
            do {
                note = try BeamNote.fetchOrCreate(self, tabGroupId: frozenGroup.id)
            } catch {
                throw TabGroupSharingError.couldntCreateNote
            }
            guard note?.save(self) == true else {
                throw TabGroupSharingError.couldntSaveNote
            }
        }
        guard let note = note else {
            throw TabGroupSharingError.couldntCreateNote
        }
        return (note, groupUsed)
    }

    /// - Returns: true if save was successful
    @MainActor
    func addGroup(_ group: TabGroup, toNote note: BeamNote) async -> Bool {
        var newTitle: String?
        if group.title?.isEmpty != false {
            newTitle = TabGroupingStoreManager.suggestedDefaultTitle(for: group, withTabs: allOpenTabs(inGroup: group), truncated: false)
        }
        let copiedGroup = await self.copyForNoteInsertion(group, newTitle: newTitle)
        note.addTabGroup(copiedGroup.id)
        if note.save(self) {
            Logger.shared.logInfo("Added group '\(copiedGroup.descriptionForLogs)' into note '\(note)'", category: .tabGrouping)
            return true
        } else {
            Logger.shared.logInfo("Failed to add group '\(copiedGroup.descriptionForLogs)' into note '\(note)'", category: .tabGrouping)
            return false
        }
    }

    func findNoteContainingGroup(_ groupId: TabGroup.GroupID) async -> [BeamNote] {
        await withCheckedContinuation { continuation in
            BeamData.shared.noteLinksAndRefsManager?.search(containingTabGroup: groupId) { result in
                switch result {
                case .success(let searchResults):
                    let notes = searchResults.compactMap { BeamNote.fetch(id: $0.noteId) }
                    continuation.resume(returning: notes)
                case .failure:
                    continuation.resume(returning: [])
                }
            }
        }
    }
}
