//
//  AllNotesPageContentViewModel.swift
//  Beam
//
//  Created by Remi Santos on 16/03/2022.
//

import SwiftUI
import Combine
import BeamCore

class AllNotesPageViewModel: ObservableObject, Identifiable {
    var data: BeamData?
    @Published private var allNotes = [DocumentStruct]() {
        didSet {
            updateNoteItemsFromAllNotes()
        }
    }
    @Published var username: String?
    @Published var isAuthenticated: Bool = false
    private var signinScope = Set<AnyCancellable>()

    @Published var allNotesItems = [NoteTableViewItem]()
    @Published var privateNotesItems = [NoteTableViewItem]()
    @Published var publicNotesItems = [NoteTableViewItem]()
    @Published var shouldReloadData: Bool? = false
    @Published var publishingNoteTitle: String?

    private var coreDataObservers = Set<AnyCancellable>()
    private var metadataFetchers = Set<AnyCancellable>()
    private var notesCancellables = Set<AnyCancellable>()
    private var notesMetadataCache: NoteListMetadataCache {
        NoteListMetadataCache.shared
    }

    init() {
        CoreDataContextObserver.shared
            .publisher(for: .anyDocumentChange)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAllNotes()
            }
            .store(in: &coreDataObservers)
        NotificationCenter.default
            .publisher(for: .defaultDatabaseUpdate, object: nil)
            .sink { [weak self] _ in
                self?.refreshAllNotes()
            }
            .store(in: &notesCancellables)

        username = AuthenticationManager.shared.username
        isAuthenticated = AuthenticationManager.shared.isAuthenticated
        AuthenticationManager.shared.isAuthenticatedPublisher.receive(on: DispatchQueue.main).sink { [weak self] isAuthenticated in
            self?.isAuthenticated = isAuthenticated
            self?.username = AuthenticationManager.shared.username
        }.store(in: &signinScope)
    }

    func refreshAllNotes() {
        allNotes = DocumentManager().loadAll()
    }

    /// We're hiding empty journal notes; except for today's
    private func noteShouldBeDisplayed(_ doc: DocumentStruct) -> Bool {
        if doc.title == publishingNoteTitle {
            return false
        }
        return doc.documentType != .journal || !doc.isEmpty || doc.journalDate == BeamNoteType.todaysJournal.journalDateString
    }

    private func updateNoteItemsFromAllNotes() {
        allNotesItems = allNotes.compactMap { doc in
            guard noteShouldBeDisplayed(doc) else { return nil }
            let note = BeamNote.getFetchedNote(doc.id)
            let item = NoteTableViewItem(document: doc, note: note)
            if let metadata = notesMetadataCache.metadata(for: item.id) {
                item.mentions = metadata.mentions
                if item.words < 0 {
                    item.words = metadata.wordsCount
                }
            }
            return item
        }
        updatePublicPrivateLists()
        asyncComputeNotesMetadata(notesItems: allNotesItems)
    }

    private func updatePublicPrivateLists() {
        publicNotesItems = allNotesItems.filter({ $0.isPublic })
        privateNotesItems = allNotesItems.filter({ !$0.isPublic })
    }

    private func updateMetadatasForItems(with fetchedNotes: [UUID: BeamNote]) {
        var shouldReload = false
        allNotesItems = allNotesItems.map { item in
            if let metadata = notesMetadataCache.metadata(for: item.id), let note = fetchedNotes[item.id] {
                item.mentions = metadata.mentions
                item.words = metadata.wordsCount
                item.note = note
                shouldReload = true
            }
            return item
        }
        updatePublicPrivateLists()
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
            DispatchQueue.global(qos: .userInteractive).async {
                notesItems.forEach { item in
                    guard item.note == nil || item.mentions < 0 else { return }
                    guard let note = item.note ?? item.getNote() else { return }
                    let mentions = note.mentionsCount
                    let metadata = NoteListMetadata(mentions: mentions, wordsCount: note.textStats.wordsCount)
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

    func showConnectWindow() {
        let onboardingManager = data?.onboardingManager
        onboardingManager?.prepareForConnectOnly()
        onboardingManager?.presentOnboardingWindow()
    }
}

extension AllNotesPageViewModel: AllNotesPageContextualMenuDelegate {
    func contextualMenuWillDeleteDocuments(ids: [UUID], all: Bool) {
        if all {
            allNotes.removeAll()
        } else {
            allNotes.removeAll { ids.contains($0.id) }
        }
    }
}

@objcMembers
class NoteTableViewItem: TableViewItem {
    var id: UUID { note?.id ?? document.id }
    var isPublic: Bool { note?.publicationStatus.isPublic ?? document.isPublic }
    var note: BeamNote? {
        didSet {
            words = note?.textStats.wordsCount ?? words
        }
    }
    private var document: DocumentStruct

    var title: String
    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    var words: Int = -1
    var mentions: Int = -1

    init(document: DocumentStruct, note: BeamNote?) {
        self.note = note
        self.document = document
        title = note?.title ?? document.title
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        words = note?.textStats.wordsCount ?? -1
    }

    func getNote() -> BeamNote? {
        note ?? BeamNote.fetch(id: id, includeDeleted: false, keepInMemory: false, decodeChildren: false)
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let otherNote = object as? NoteTableViewItem else { return false }
        return note?.id == otherNote.note?.id
    }
}
