//
//  NodeHeaderViewModel.swift
//  Beam
//
//  Created by Remi Santos on 24/11/2021.
//

import Foundation
import BeamCore
import Combine

extension NoteHeaderView {
    enum CopyLinkSource {
        case fromLinkIcon
        case fromPublishButton
    }

    final class ViewModel: ObservableObject {
        @Published var note: BeamNote? {
            didSet {
                guard note != oldValue else { return }
                updateOnNoteChanged()
            }
        }
        weak var state: BeamState?

        // title editing
        @Published var titleText: String = ""
        @Published var titleSelectedRange: Range<Int>?
        @Published var isEditingTitle: Bool = false
        @Published var isTitleTaken: (value: Bool, animated: Bool) = (false, true)
        @Published var wiggleValue: CGFloat = .zero

        // publishing
        @Published var publishState: NoteHeaderPublishButton.PublishButtonState = .isPrivate
        @Published var isOnUserProfile: Bool = false
        @Published var justCopiedLinkFrom: NoteHeaderView.CopyLinkSource?
        var profileLink: URL?
        private var publishingDispatchItem: DispatchWorkItem?
        private var copyLinkDispatchItem: DispatchWorkItem?
        private var noteObservers = Set<AnyCancellable>()

        var canEditTitle: Bool {
            note?.type.isJournal == false
        }

        init(note: BeamNote? = nil, state: BeamState? = nil) {
            self.state = state
            self.note = note
        }

        private func updateOnNoteChanged() {
            self.noteObservers.removeAll()
            if let note = note {
                note.$publicationStatus.dropFirst().removeDuplicates().sink { [weak self] newValue in
                    guard self?.publishState == .isPublic || self?.publishState == .isPrivate else { return }
                    self?.publishState = newValue.isPublic ? .isPublic : .isPrivate
                    self?.isOnUserProfile = newValue.isOnPublicProfile
                }.store(in: &noteObservers)
                note.$title.dropFirst().sink { [weak self] newTitle in
                    guard self?.isEditingTitle != true && self?.titleText != newTitle else { return }
                    self?.titleText = newTitle
                }.store(in: &noteObservers)
            }
            resetEditingState(animated: false)
            self.publishState = note?.publicationStatus.isPublic == true ? .isPublic : .isPrivate
            self.isOnUserProfile = note?.publicationStatus.isOnPublicProfile ?? false
        }

        func textFieldDidChange(_ text: String) {
            titleSelectedRange = nil
            let newTitle = formatToValidTitle(titleText)
            let existingNote = DocumentManager().loadDocumentByTitle(title: newTitle)
            self.isTitleTaken = (existingNote != nil && existingNote?.id != note?.id, true)
        }

        func resetEditingState(animated: Bool = true) {
            titleText = note?.title ?? ""
            isEditingTitle = false
            isTitleTaken = (false, animated)
            wiggleValue = 0
        }

        func formatToValidTitle(_ title: String) -> String {
            return BeamNote.validTitle(fromTitle: title)
        }

        func commitRenameCard(fromTextField: Bool) {
            let newTitle = formatToValidTitle(titleText)
            guard !newTitle.isEmpty, newTitle != note?.title, !isTitleTaken.value, canEditTitle else {
                if fromTextField && isTitleTaken.value {
                    wiggleValue += 1
                } else {
                    resetEditingState()
                }
                return
            }
            note?.updateTitle(newTitle)
            isEditingTitle = false
        }

        func focusTitle() {
            titleSelectedRange = titleText.wholeRange.upperBound..<titleText.wholeRange.upperBound
            isEditingTitle = true
        }

        func onTap() {
            guard canEditTitle else { return }
            titleSelectedRange = nil
            // wait to see if double tap happened
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard !self.isEditingTitle else { return }
                self.focusTitle()
            }
        }

        func onDoubleTap() {
            guard canEditTitle else { return }
            titleSelectedRange = titleText.wholeRange
            isEditingTitle = true
        }

        // MARK: Link
        func getLink() -> URL? {
            guard let note = note else { return nil }
            return BeamNoteSharingUtils.getPublicLink(for: note)
        }

        func copyLink(source: NoteHeaderView.CopyLinkSource) {
            guard let note = note else { return }
            BeamNoteSharingUtils.copyLinkToClipboard(for: note) { [weak self] _ in
                self?.justCopiedLinkFrom = source
                self?.copyLinkDispatchItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    self?.justCopiedLinkFrom = nil
                }
                self?.copyLinkDispatchItem = workItem
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(2)), execute: workItem)
            }
        }

        func getProfileLink() -> URL? {
            BeamNoteSharingUtils.getProfileLink()
        }

        // MARK: - Publication Groups
        func togglePublishOnProfile(completion: @escaping ((Result<Bool, Error>) -> Void)) {
            let missingRequirement: Result<Bool, Error> = Result.failure(BeamNoteSharingUtilsError.missingRequirement)

            guard let note = note, note.publicationStatus.isPublic,
                  var publicationGroups = note.publicationStatus.publicationGroups else {
                completion(missingRequirement)
                return
            }

            if note.publicationStatus.isOnPublicProfile {
                guard let idx = publicationGroups.firstIndex(where: { $0 == "profile" }) else { return }
                publicationGroups.remove(at: idx)
            } else {
                publicationGroups.append("profile")
            }

            BeamNoteSharingUtils.updatePublicationGroup(note, publicationGroups: publicationGroups) { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }
            return
        }

        // MARK: Publishing
        /// returns true if user is allowed to perform the action
        func togglePublish(completion: @escaping ((Result<Bool, Error>) -> Void)) -> Bool {
            let missingRequirement: Result<Bool, Error> = Result.failure(BeamNoteSharingUtilsError.missingRequirement)

            guard let note = note else {
                completion(missingRequirement)
                return false
            }

            guard ![.publishing, .unpublishing].contains(publishState) else {
                completion(missingRequirement)
                return true
            }
            let isPublic = note.publicationStatus.isPublic

            guard isPublic || BeamNoteSharingUtils.canMakePublic else {
                completion(missingRequirement)
                return false
            }
            if !isPublic {
                publishState = .publishing
                BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true) { [weak self] result in
                    DispatchQueue.main.async {
                        guard case .success(let published) = result, published == true else {
                            self?.noteBecamePublic(false)
                            completion(result)
                            return
                        }
                        self?.noteBecamePublic(true)
                        self?.copyLink(source: .fromPublishButton)
                        completion(result)
                    }
                }
            } else {
                promptConfirmUnpublish(completion: completion)
            }
            return true
        }

        private func noteBecamePublic(_ value: Bool, debounce: Bool = true) {
            publishingDispatchItem?.cancel()
            if debounce {
                publishState = value ? .justPublished : .justUnpublished
                let workItem = DispatchWorkItem { [weak self] in
                    self?.publishState = value ? .isPublic : .isPrivate
                }
                publishingDispatchItem = workItem
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(2)), execute: workItem)
            } else {
                publishState = value ? .isPublic : .isPrivate
            }
        }

        private func promptConfirmUnpublish(completion: @escaping ((Result<Bool, Error>) -> Void)) {
            let missingRequirement: Result<Bool, Error> = Result.failure(BeamNoteSharingUtilsError.missingRequirement)

            guard let note = note else {
                completion(missingRequirement)
                return
            }
            let alert = NSAlert()
            alert.messageText = "Are you sure you want to unpublish the note \"\(note.title)\"?"
            alert.informativeText = "Others will no longer have access to this note."
            alert.addButton(withTitle: "Unpublish")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            guard let window = AppDelegate.main.window else { return }
            alert.beginSheetModal(for: window) { [weak self] response in
                guard let self = self, let note = self.note else {
                    completion(missingRequirement)
                    return
                }
                guard response == .alertFirstButtonReturn else {
                    self.publishState = note.publicationStatus.isPublic == true ? .isPublic : .isPrivate
                    completion(Result.failure(BeamNoteSharingUtilsError.canceled))
                    return
                }
                self.publishState = .unpublishing
                BeamNoteSharingUtils.makeNotePublic(note, becomePublic: false) { [weak self] result in
                    defer {
                        DispatchQueue.main.async {
                            completion(result)
                        }
                    }
                    guard case .success(let published) = result, published == false else {
                        DispatchQueue.main.async {
                            self?.noteBecamePublic(note.publicationStatus.isPublic)
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        self?.noteBecamePublic(false)
                    }
                }
            }
        }

        // MARK: Delete
        func deleteNote() {
            guard let note = note, let state = state else { return }
            note.promptConfirmDelete(for: state)
        }
    }
}
