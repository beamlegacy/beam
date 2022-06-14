//
//  PinnedNotesManager.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 24/05/2022.
//

import Foundation
import Combine
import BeamCore

class PinnedNotesManager: ObservableObject {

    private let documentManager: DocumentManager
    private var scope = Set<AnyCancellable>()
    private var documentManagerCancellables = Set<AnyCancellable>()

    @Published private(set) var pinnedNotes = [BeamNote]() {
        didSet {
            let ids = pinnedNotes.map { $0.id.uuidString }
            Persistence.PinnedNotes.pinnedNotesId = ids
        }
    }

    private var maxNumberOfPinnedNotes: Int? {
        let maxNumberOfPinnedNotesWithTabSwitcher = 5
        guard let useSidebar = AppDelegate.main.window?.state.useSidebar, useSidebar else { return maxNumberOfPinnedNotesWithTabSwitcher }
        return nil
    }

    private var numberOfAvalaiblePinSlots: Int? {
        guard let maxNumberOfPinnedNotes = maxNumberOfPinnedNotes else {
            return nil
        }
        return maxNumberOfPinnedNotes - pinnedNotes.count
    }

    init(with documentManager: DocumentManager) {
        self.documentManager = documentManager
        self.fetchPinned()
        self.observeDocumentManager()

        NotificationCenter.default
            .publisher(for: .defaultDatabaseUpdate, object: nil)
            .sink { [weak self] _ in
                self?.fetchPinned()
            }
            .store(in: &scope)
    }

    private func fetchPinned() {
        guard let pinnedIds = Persistence.PinnedNotes.pinnedNotesId else { return }
        let pinnedNotes = pinnedIds.compactMap { id -> BeamNote? in
            if let uuid = UUID(uuidString: id), let note = BeamNote.fetch(id: uuid, includeDeleted: false) {
                return note
            }
            return nil
        }
        self.pinnedNotes = pinnedNotes
    }

    private func observeDocumentManager() {
        documentManagerCancellables.removeAll()
        DocumentManager.documentDeleted.receive(on: DispatchQueue.main)
            .sink { [weak self] docId in
                if let index = self?.pinnedNotes.firstIndex(where: { $0.id == docId }) {
                    self?.pinnedNotes.remove(at: index)
                }
            }.store(in: &scope)
    }

    func canPin(notes: [BeamNote]) -> Bool {
        if let numberOfAvalaiblePinSlots = numberOfAvalaiblePinSlots, numberOfAvalaiblePinSlots - notes.filter({!isPinned($0)}).count < 0 {
            return false
        }
        return true
    }

    func pin(notes: [BeamNote]) {
        if !canPin(notes: notes) {
            alertTooManyPinnedNotes()
            return
        }
        notes.forEach({
            guard !pinnedNotes.contains($0) else { return }
            pinnedNotes.append($0)
        })
    }

    func unpin(notes: [BeamNote]) {
        notes.forEach({
            guard let index = pinnedNotes.firstIndex(of: $0) else { return }
            pinnedNotes.remove(at: index)
        })
    }

    func unpinAll() {
        pinnedNotes.removeAll()
    }

    func togglePin(_ note: BeamNote) {
        let isPinned = isPinned(note)
        isPinned ? unpin(notes: [note]) : pin(notes: [note])
    }

    func isPinned(_ note: BeamNote) -> Bool {
        pinnedNotes.contains(note)
    }

    private func alertTooManyPinnedNotes() {
        guard AppDelegate.main.window != nil else { return }
        UserAlert.showMessage(message: "Too many pinned notes", informativeText: "You can only have 5 pinned notes.\nUnpin some notes to pin new ones.", buttonTitle: "OK")
    }
}
