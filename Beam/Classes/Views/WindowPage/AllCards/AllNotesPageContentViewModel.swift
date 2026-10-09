//
//  AllNotesPageContentViewModel.swift
//  Beam
//
//  Created by Remi Santos on 16/03/2022.
//

import SwiftUI
import Combine
import BeamCore

final class AllNotesPageViewModel: ObservableObject, Identifiable {
    @Published private var allNotes = [BeamDocument]() {
        didSet {
            updateNoteItemsFromAllNotes()
        }
    }
    @Published var allNotesItems = [NoteTableViewItem]()
    @Published var shouldReloadData: Bool? = false

    private var showDailyNotes = true
    @Published var showTabGroupNotes = false

    private var databaseObservers = Set<AnyCancellable>()
    private var metadataFetchers = Set<AnyCancellable>()
    private var notesCancellables = Set<AnyCancellable>()
    private var notesMetadataCache: NoteListMetadataCache {
        NoteListMetadataCache.shared
    }

    init() {
        BeamDocumentCollection.documentSaved
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAllNotes()
            }
            .store(in: &databaseObservers)

        BeamDocumentCollection.documentDeleted
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAllNotes()
            }
            .store(in: &databaseObservers)

        BeamData.shared.currentDatabaseChanged
            .sink { [weak self] _ in
                self?.refreshAllNotes()
            }
            .store(in: &notesCancellables)
    }

    func refreshAllNotes() {
        guard let collection = BeamData.shared.currentDocumentCollection else { return }
        allNotes = (try? collection.fetch(filters: [])) ?? []
    }

    func setShowDailyNotes(_ show: Bool) {
        showDailyNotes = show
        updateNoteItemsFromAllNotes()
    }

    func setShowTabGroupNotes(_ show: Bool) {
        showTabGroupNotes = show
        updateNoteItemsFromAllNotes()
    }

    /// We're hiding empty journal notes; except for today's
    private func noteShouldBeDisplayed(_ doc: BeamDocument) -> Bool {
        return doc.documentType != .journal || !doc.isEmpty || doc.journalDate >= BeamNoteType.intFrom(journalDate: BeamDate.now) || doc.isReferencedOrLinked
    }

    private func updateNoteItemsFromAllNotes() {
        allNotesItems = allNotes.compactMap { doc in
            guard noteShouldBeDisplayed(doc) else { return nil }
            let note = BeamNote.getFetchedNote(doc.id)
            let item = NoteTableViewItem(document: doc, note: note)
            if let metadata = notesMetadataCache.metadata(for: item.id) {
                item.links = metadata.links
                if item.words < 0 {
                    item.words = metadata.wordsCount
                }
            }
            return item
        }
        applyFilters()
        asyncComputeNotesMetadata(notesItems: allNotesItems)
    }

    private func applyFilters() {
        if !showDailyNotes {
            allNotesItems = allNotesItems.filter { $0.isJournal == false }
        }
        if !showTabGroupNotes {
            allNotesItems = allNotesItems.filter { $0.isTabGroup == false }
        }
    }

    private func updateMetadatasForItems(with fetchedNotes: [UUID: BeamNote]) {
        var shouldReload = false
        allNotesItems = allNotesItems.map { item in
            if let metadata = notesMetadataCache.metadata(for: item.id), let note = fetchedNotes[item.id] {
                item.links = metadata.links
                item.words = metadata.wordsCount
                item.note = note
                shouldReload = true
            }
            return item
        }
        applyFilters()
        shouldReloadData = shouldReload
    }

    private func asyncComputeNotesMetadata(notesItems: [NoteTableViewItem]) {
        metadataFetchers.removeAll()
        fetchAllNotesMetadata(for: notesItems)
            .receive(on: DispatchQueue.main)
            .sink { fetchedNotes in
                self.updateMetadatasForItems(with: fetchedNotes)
            }
            .store(in: &metadataFetchers)
    }

    private func fetchAllNotesMetadata(for notesItems: [NoteTableViewItem]) -> AnyPublisher<[UUID: BeamNote], Never> {
        Future { promise in
            var metadatas = [UUID: NoteListMetadata]()
            var fetchedNotes = [UUID: BeamNote]()
            DispatchQueue.userInteractive.async {
                notesItems.forEach { item in
                    guard let note = item.note ?? item.getNote() else { return }
                    guard item.links != note.links.count || item.note == nil || item.links < 0 else { return }
                    let metadata = NoteListMetadata(links: note.links.count, wordsCount: note.textStats.wordsCount)
                    metadatas[item.id] = metadata
                    fetchedNotes[item.id] = note
                }
                DispatchQueue.main.async {
                    metadatas.forEach { key, value in
                        NoteListMetadataCache.shared.saveMetadata(value, for: key)
                    }
                    promise(.success(fetchedNotes))
                }
            }
        }.eraseToAnyPublisher()
    }
}

extension AllNotesPageViewModel: AllNotesPageContextualMenuDelegate {

    func contextualMenuWillUndoRedoDeleteDocuments() {
        self.refreshAllNotes()
    }

    func contextualMenuWillDeleteDocuments(ids: [UUID], all: Bool) {
        if all {
            allNotes.removeAll()
        } else {
            allNotes.removeAll { ids.contains($0.id) }
        }
    }
}

@objcMembers
class NoteTableViewItem: IconButtonTableViewItem {
    var id: UUID { note?.id ?? document.id }
    var note: BeamNote? {
        didSet {
            words = note?.textStats.wordsCount ?? words
        }
    }
    private var document: BeamDocument

    var title: String
    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    var isJournal: Bool = false
    var isTabGroup: Bool = false
    var words: Int = -1
    var links: Int = -1

    init(document: BeamDocument, note: BeamNote?) {
        self.note = note
        self.document = document
        title = note?.title ?? document.title
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        isJournal = (document.journalDate != 0 && document.documentType == .journal)
        isTabGroup = document.documentType == .tabGroup
        words = note?.textStats.wordsCount ?? -1

        super.init()
    }

    func getNote() -> BeamNote? {
        note ?? BeamNote.fetch(id: id, keepInMemory: false, decodeChildren: false)
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let otherNote = object as? NoteTableViewItem else { return false }
        return note?.id == otherNote.note?.id && updatedAt == otherNote.updatedAt
    }
}
