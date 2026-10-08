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
    final class ViewModel: ObservableObject, BeamDocumentSource {
        static var sourceId: String { "NoteHeaderView_\(Self.self)" }

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

        private var noteObservers = Set<AnyCancellable>()

        @Published private(set) var tabGroupObjects: [TabGroupBeamObject]

        var canEditTitle: Bool {
            note?.type.isJournal == false
        }

        init(note: BeamNote? = nil, state: BeamState? = nil) {
            self.state = state
            self.note = note

            tabGroupObjects = []
            if let savedUUIDs = note?.tabGroups {
                setTabGroups(with: savedUUIDs)
            }
        }

        private func updateOnNoteChanged() {
            self.noteObservers.removeAll()
            if let note = note {
                note.$title.dropFirst().sink { [weak self] newTitle in
                    guard self?.isEditingTitle != true && self?.titleText != newTitle else { return }
                    self?.titleText = newTitle
                }.store(in: &noteObservers)
            }
            resetEditingState(animated: false)
        }

        func textFieldDidChange(_ text: String) {
            guard let collection = BeamData.shared.currentDocumentCollection else { return }
            titleSelectedRange = nil
            let newTitle = formatToValidTitle(titleText)
            let existingNote = try? collection.fetchFirst(filters: [.title(newTitle)])
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
            note?.updateTitle(self, newTitle)
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

        // MARK: Delete
        func deleteNote(undoManager: UndoManager?) {
            guard let note = note, let state = state else { return }
            note.promptConfirmDelete(state: state, undoManager: undoManager)
        }

        // MARK: - Pin note
        var isPinned: Bool {
            guard let state = state, let note = note else {
                return false
            }
            return state.data.pinnedManager.isPinned(note)
        }

        func togglePin() {
            guard let state = state, let note = note else {
                return
            }
            state.data.pinnedManager.togglePin(note)
        }

        // MARK: - TabGroup
        func setTabGroups(with tabGroupIds: [UUID]) {
            guard let storeManager = state?.data.tabGroupingDBManager else { return }
            let tabs = storeManager.fetch(byIds: tabGroupIds)
            self.tabGroupObjects = tabs
        }
    }
}
