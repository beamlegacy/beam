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
    func shareGroup(_ group: TabGroup, shareService: ShareService = .copy, completion: ((Result<URL, TabGroupSharingError>) -> Void)?) -> Bool {
        do {
            guard BeamNoteSharingUtils.canMakePublic else {
                throw TabGroupSharingError.notAuthenticated
            }
            group.status = .sharing
            let note = try fetchOrCreateTabGroupNote(for: group)
            BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true) { [weak self] result in
                group.status = .default
                guard case .success = result, let url = BeamNoteSharingUtils.getPublicLink(for: note) else {
                    self?.showShareGroupError(error: .publicationError, forGroup: group)
                    completion?(.failure(.publicationError))
                    return
                }
                self?.handleShareGroupService(forURL: url, with: shareService)
                completion?(.success(url))
            }
            return true
        } catch {
            group.status = .default
            Logger.shared.logError("Couldn't share Tab Group (\(group.id)) - \(error.localizedDescription)", category: .tabGrouping)
            let shareError = error as? TabGroupSharingError ?? .couldntCreateNote
            showShareGroupError(error: shareError, forGroup: group)
            completion?(.failure(shareError))
            return false
        }
    }

    private func handleShareGroupService(forURL url: URL, with shareService: ShareService) {
        let shareHelper = ShareHelper(url) { url in
            guard let mainState = AppDelegate.main.window?.state else { return }
            let dumTab = BrowserTab(state: mainState, browsingTreeOrigin: nil, originMode: .web, note: nil)
            let webView = dumTab.createNewWindow(URLRequest(url: url), dumTab.webView.configuration,
                                                 windowFeatures: ShareWindowFeatures(for: shareService), setCurrent: true)
            _ = webView.load(URLRequest(url: url))
        }
        Task {
            await shareHelper.shareContent("", originURL: url, service: shareService)
        }
    }

    /// checks if group is already shared and in a tab group note.
    private func fetchTabGroupNote(for group: TabGroup) -> BeamNote? {
        var note: BeamNote?
        if group.isLocked, let groupNote = BeamNote.fetch(tabGroupId: group.id) {
            return groupNote
        }
        TabGroupingStoreManager.shared?.fetch(copiesOfGroup: group.id).forEach { groupBeamObject in
            guard note == nil else { return }
            note = BeamNote.fetch(tabGroupId: groupBeamObject.id)
        }
        return note
    }

    private func fetchOrCreateTabGroupNote(for group: TabGroup) throws -> BeamNote {
        var note: BeamNote? = fetchTabGroupNote(for: group)
        if note == nil {
            let frozenGroup = self.copyForSharing(group)
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
        return note
    }

    private func showShareGroupError(error: TabGroupSharingError, forGroup group: TabGroup) {
        if error == .notAuthenticated {
            BeamData.shared.onboardingManager.showOnboardingForConnectOnly(withConfirmationAlert: true)
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
        let copiedGroup = self.copyForNoteInsertion(group)
        if copiedGroup.title == nil || copiedGroup.title?.isEmpty == true  {
            let title = TabGroupingStoreManager.suggestedDefaultTitle(for: group, withTabs: allOpenTabs(), truncated: false)
            renameGroup(copiedGroup, title: title)
        }
        note.addTabGroup(copiedGroup.id)
        if note.save(self) {
            Logger.shared.logInfo("Added group \(copiedGroup.title ?? "Unnamed"), id: \(copiedGroup.id.uuidString) into note \(note) id: \(note.id)", category: .tabGrouping)
            return true
        } else {
            Logger.shared.logInfo("Failed to add group \(copiedGroup.title ?? "Unnamed"), id: \(copiedGroup.id.uuidString) into note \(note) id: \(note.id)", category: .tabGrouping)
            return false
        }
    }
}
