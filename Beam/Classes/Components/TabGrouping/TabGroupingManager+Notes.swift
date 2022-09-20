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
        case notAuthenticated
        case publicationError
    }

    /// Will make all the necessary steps to share a tab group. And returns the public URL.
    ///
    /// It will
    /// - create the corresponding tabGroup note (or update existing one).
    /// - publish that note to the public api.
    /// - use shareService to copy or open share sheet for the public url.
    /// - display an user alert if there was an error in the process.
    ///
    /// - Returns: `true` if the group can be shared.
    @discardableResult
    func shareGroup(_ group: TabGroup, shareService: ShareService = .copy, state: BeamState, completion: ((Result<URL, TabGroupSharingError>) -> Void)?) -> Bool {
        do {
            guard BeamNoteSharingUtils.canMakePublic,
                  let fileManager = state.data.fileDBManager
            else {
                throw TabGroupSharingError.notAuthenticated
            }
            Logger.shared.logInfo("Sharing Tab Group '\(group.descriptionForLogs)'...", category: .tabGrouping)
            group.status = .sharing
            let shouldSaveParentGroup = !group.isLocked
            if !group.isLocked {
                // once we started sharing a group, we don't want clustering to update it anymore.
                // even if we're going to make an actual copy, user might be scared if the parent is being updated.
                group.lockGroup()
            }

            let (note, groupCopy) = try fetchOrCreateTabGroupNote(for: group)
            Task { @MainActor in
                if shouldSaveParentGroup {
                    await saveGroupToDBIfNeeded(group, copyOf: nil)
                }
                await saveGroupToDBIfNeeded(groupCopy, copyOf: group)
                BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true, fileManager: fileManager) { [weak self] result in
                    group.status = .default
                    guard case .success = result, let url = BeamNoteSharingUtils.getPublicLink(for: note) else {
                        self?.showShareGroupError(error: .publicationError, forGroup: group)
                        Logger.shared.logError("Couldn't share Tab Group, Publication Error, '\(group.descriptionForLogs)'", category: .tabGrouping)
                        completion?(.failure(.publicationError))
                        return
                    }
                    self?.handleShareGroupService(forURL: url, with: shareService, data: state.data)
                    Logger.shared.logInfo("Tab Group Shared '\(group.descriptionForLogs)'", category: .tabGrouping)
                    completion?(.success(url))
                }
            }
            return true
        } catch {
            group.status = .default
            Logger.shared.logError("Couldn't share Tab Group '\(group.descriptionForLogs)' - \(error.localizedDescription)", category: .tabGrouping)
            let shareError = error as? TabGroupSharingError ?? .couldntCreateNote
            showShareGroupError(error: shareError, forGroup: group)
            completion?(.failure(shareError))
            return false
        }
    }

    @MainActor
    private func saveGroupToDBIfNeeded(_ group: TabGroup, copyOf parentGroup: TabGroup?) async {
        var group = group
        let openedTabsInThisGroup = allOpenTabs(inGroup: parentGroup ?? group)
        if storeManager?.fetch(byIds: [group.id]).first == nil || !openedTabsInThisGroup.isEmpty {
            // first save or update the existing group
            if let parentGroup = parentGroup, group != parentGroup {
                var title = parentGroup.title?.isEmpty == false ? parentGroup.title : group.title
                if title?.isEmpty != false {
                    title = TabGroupingStoreManager.suggestedDefaultTitle(for: parentGroup,
                                                                          withTabs: openedTabsInThisGroup,
                                                                          truncated: false)
                }
                group = .init(id: group.id, pageIds: parentGroup.pageIds,
                              title: title,
                              color: parentGroup.color ?? group.color,
                              isLocked: group.isLocked, parentGroup: group.parentGroup)
            }
            await storeManager?.groupDidUpdate(group, origin: .sharing, updatePagesWithOpenedTabs: openedTabsInThisGroup)
        }
    }

    private func handleShareGroupService(forURL url: URL, with shareService: ShareService, data: BeamData) {
        let shareHelper = ShareHelper(url, data: data) { url in
            guard let mainState = AppDelegate.main.window?.state else { return }
            let dumTab = BrowserTab(state: mainState, browsingTreeOrigin: nil, originMode: .web, note: nil)
            let webView = dumTab.createNewWindow(URLRequest(url: url), dumTab.webView.configuration,
                                                 windowFeatures: ShareWindowFeatures(for: shareService), setCurrent: true)
            _ = webView.load(URLRequest(url: url))
        }
        Task {
            await shareHelper.shareContent([], originURL: url, service: shareService)
        }
    }

    /// checks if group is already shared and in a tab group note.
    func fetchTabGroupNote(for group: TabGroup) -> (BeamNote, TabGroup)? {
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

    func fetchOrCreateTabGroupNote(for group: TabGroup) throws -> (BeamNote, TabGroup) {
        let result = fetchTabGroupNote(for: group)
        var note = result?.0
        var groupUsed = result?.1 ?? group
        if result == nil {
            let frozenGroup = self.copyForSharing(group)
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

    private func showShareGroupError(error: TabGroupSharingError, forGroup group: TabGroup) {
        if error == .notAuthenticated {
            BeamData.shared.onboardingManager.showOnboardingForConnectOnly(withConfirmationAlert: true,
                                                                           message: loc("Connect to Beam to share your tab groups."))
            return
        }
        var groupTitle = group.title ?? ""
        if !groupTitle.isEmpty {
            groupTitle = "“\(groupTitle)” "
        }
        UserAlert.showMessage(message: loc("Cannot share tab group"),
                              informativeText: "The tab group \(groupTitle)cannot be shared. Check your Internet connection and try again.",
                              buttonTitle: loc("OK"))
    }

    /// - Returns: true if save was successful
    func addGroup(_ group: TabGroup, toNote note: BeamNote) -> Bool {
        var newTitle: String?
        if group.title?.isEmpty != false {
            newTitle = TabGroupingStoreManager.suggestedDefaultTitle(for: group, withTabs: allOpenTabs(inGroup: group), truncated: false)
        }
        let copiedGroup = self.copyForNoteInsertion(group, newTitle: newTitle)
        note.addTabGroup(copiedGroup.id)
        if note.save(self) {
            Logger.shared.logInfo("Added group '\(copiedGroup.descriptionForLogs)' into note '\(note)'", category: .tabGrouping)
            return true
        } else {
            Logger.shared.logInfo("Failed to add group '\(copiedGroup.descriptionForLogs)' into note '\(note)'", category: .tabGrouping)
            return false
        }
    }

    func findNoteContainingGroup(_ group: TabGroup) async -> [BeamNote] {
        await withCheckedContinuation { continuation in
            BeamData.shared.noteLinksAndRefsManager?.search(containingTabGroup: group.id) { result in
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
