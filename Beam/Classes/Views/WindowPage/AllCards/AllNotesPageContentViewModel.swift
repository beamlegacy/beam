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

    private struct PersistedState {
        var sortDescriptor: NSSortDescriptor?
    }
    static private var persistedState = PersistedState()

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
    @Published var onProfileNotesItems = [NoteTableViewItem]()
    @Published var shouldReloadData: Bool? = false
    @Published var publishingNoteTitle: String?
    @Published var showDailyNotes: Bool = true {
        didSet {
            updateNoteItemsFromAllNotes()
        }
    }

    private var coreDataObservers = Set<AnyCancellable>()
    private var metadataFetchers = Set<AnyCancellable>()
    private var notesCancellables = Set<AnyCancellable>()
    private var notesMetadataCache: NoteListMetadataCache {
        NoteListMetadataCache.shared
    }
    var sortDescriptor: Binding<NSSortDescriptor?> {
        .init {
            Self.persistedState.sortDescriptor
        } set: {
            Self.persistedState.sortDescriptor = $0
        }
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

    func getCurrentNotesList(for type: AllNotesPageContentView.ListType) -> [NoteTableViewItem] {
        switch type {
        case .publicNotes:
            return publicNotesItems
        case .privateNotes:
            return privateNotesItems
        case .onProfileNotes:
            return onProfileNotesItems
        default:
            return allNotesItems
        }
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
        if !showDailyNotes {
            allNotesItems = allNotesItems.filter { $0.isJournal == false }
        }
        publicNotesItems = allNotesItems.filter({ $0.isPublic })
        onProfileNotesItems = publicNotesItems.filter({ $0.isOnProfile })
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

    func showConnectWindow(withConfirmationAlert: Bool) {
        data?.onboardingManager.showOnboardingForConnectOnly(withConfirmationAlert: withConfirmationAlert)
    }
}

extension AllNotesPageViewModel: AllNotesPageContextualMenuDelegate {

    func contextualMenuShouldPublishNote() -> Bool {
        guard BeamNoteSharingUtils.canMakePublic else {
            showConnectWindow(withConfirmationAlert: true)
            return false
        }
        return true
    }

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
    var isPublic: Bool { note?.publicationStatus.isPublic ?? document.isPublic }
    var isOnProfile: Bool { note?.publicationStatus.isOnPublicProfile ?? false }
    var note: BeamNote? {
        didSet {
            words = note?.textStats.wordsCount ?? words
        }
    }
    private var document: DocumentStruct

    var title: String
    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    var isJournal: Bool = false
    var words: Int = -1
    var mentions: Int = -1
    var copyLinkIconName: String?
    var copyAction: (() -> Void)?

    init(document: DocumentStruct, note: BeamNote?) {
        self.note = note
        self.document = document
        title = note?.title ?? document.title
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        isJournal = document.journalDate != nil
        words = note?.textStats.wordsCount ?? -1

        super.init()

        if isPublic {
            iconName = "editor-url_link"
            hasPopover = true
            popoverAlignment = .top
            buttonAction = { [weak self] point in
                guard let note = note else { return }
                if let self = self, self.hasPopover, var origin = point {
                    guard let childWindow = CustomPopoverPresenter.shared.presentPopoverChildWindow(canBecomeKey: true,
                                                                                                    canBecomeMain: false,
                                                                                                    withShadow: true,
                                                                                                    useBeamShadow: false,
                                                                                                    movable: false,
                                                                                                    autocloseIfNotMoved: true) else { return }

                    let toolTipSize = CGSize(width: 80, height: 23)
                    origin.x -= toolTipSize.width / 4
                    childWindow.setView(with: ToolTipFormatter(text: "Link Copied", size: toolTipSize), at: origin, fromTopLeft: true)
                    childWindow.makeKeyAndOrderFront(nil)

                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1300), execute: {
                        childWindow.close()
                    })
                }

                BeamNoteSharingUtils.copyLinkToClipboard(for: note)
            }
        }
    }

    func getNote() -> BeamNote? {
        note ?? BeamNote.fetch(id: id, includeDeleted: false, keepInMemory: false, decodeChildren: false)
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let otherNote = object as? NoteTableViewItem else { return false }
        return note?.id == otherNote.note?.id
    }
}
