//
//  BeamNote.swift
//
//  Created by Sebastien Metrot on 18/09/2020.
//
// swiftlint:disable file_length

import Foundation
import Combine
import Atomics

public protocol BeamNoteDocument {
    func autoSave()
    var lastChangedElement: BeamElement? { get set }
}

public enum BeamNoteError: Error, Equatable {
    case saveAlreadyRunning
    case unableToCreateDocumentStruct
    case dataIsEmpty
}

public struct VisitedPage: Codable, Identifiable {
    public var id: UUID = UUID()

    public var originalSearchQuery: String
    public var url: URL
    public var date: Date
    public var duration: TimeInterval
}

public struct BeamNoteReference: Codable, Equatable, Hashable {
    public var noteID: UUID
    public var elementID: UUID

    public init(noteID: UUID, elementID: UUID) {
        self.noteID = noteID
        self.elementID = elementID
    }
}

public enum PublicationStatus: Codable, Equatable {
    case unpublished
    case published(URL, Date)

    public var isPublic: Bool {
        switch self {
        case .published:
            return true
        default:
            return false
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .unpublished:
            try container.encode(PublicationState.unpublished, forKey: .status)
        case .published(let publicationURL, let publicationDate):
            try container.encode(PublicationState.published, forKey: .status)
            try container.encode(publicationURL, forKey: .publicationUrl)
            try container.encode(publicationDate, forKey: .publicationDate)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(PublicationState.self, forKey: .status)

        switch status {
        case .unpublished:
            self = .unpublished
        case .published:
            let publicationDate = try container.decode(Date.self, forKey: .publicationDate)
            let publicationURL = try container.decode(URL.self, forKey: .publicationUrl)
            self = .published(publicationURL, publicationDate)
        }
    }

    enum CodingKeys: String, CodingKey {
        case status
        case publicationUrl
        case publicationDate
    }

    private enum PublicationState: String, Codable {
        case unpublished
        case published
    }
}

// Document:
public class BeamNote: BeamElement {
    @Published public var title: String { didSet { change(.text) } }
    @Published public var type: BeamNoteType = .note { didSet { change(.meta) } }

    @Published public var publicationStatus: PublicationStatus = .unpublished { didSet { change(.meta) } }
    public var ongoingPublicationOperation = false

    /// Search queries whose results were used to populate this note
    @Published public var searchQueries: [String] = [] { didSet { change(.meta) } }
    /// URLs whose content were used to create this note
    @Published public var visitedSearchResults: [VisitedPage] = [] { didSet { change(.meta) } }
    public var browsingSessionIds = [UUID]() { didSet { change(.meta) } }
    public var sources = NoteSources()
    @Published public var version = ManagedAtomic<Int64>(0)
    @Published public var savedVersion = ManagedAtomic<Int64>(0)
    public var databaseId: UUID?
    @Published public var deleted: Bool = false
    @Published public var saving = ManagedAtomic<Bool>(false)
    @Published public var updateAttempts: Int = 0
    @Published public var updates: Int = 0
    public var contactId: UUID? { didSet { change(.meta) } }
    /// Tombstones is an array containing all the beamelement that once where in this note but that have been erased from it at some point.
    public var tombstones = Set<UUID>()

    public var titleAndId: String {
        "\(title) {\(id)} v\(version)"
    }

    public override var note: BeamNote? {
        return self
    }

    public override func checkHasNote() {
        hasNote = true
        for child in children {
            child.checkHasNote()
        }
    }

    public init(title: String) {
        self.title = Self.validTitle(fromTitle: title)
        super.init()
        changePropagationEnabled = false
        warmingUp = true
        defer {
            changePropagationEnabled = true
            warmingUp = false
        }

        self.sign = Self.signPost.createId(object: self)
        setupSourceObserver()
        checkHasNote()
    }

    public init(journalDate: Date) {
        self.title = BeamDate.journalNoteTitle(for: journalDate)
        self.type = BeamNoteType.journalForDate(journalDate)
        super.init()
        changePropagationEnabled = false
        warmingUp = true
        defer {
            changePropagationEnabled = true
            warmingUp = false
        }

        self.sign = Self.signPost.createId(object: self)
        setupSourceObserver()
        checkHasNote()
    }

    enum CodingKeys: String, CodingKey {
        case title
        case type
        case searchQueries
        case visitedSearchResults
        case sources
        case publicationStatus
        case browsingSessionIds
        case contactId
        case tombstones
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let ttl = try container.decode(String.self, forKey: .title)
        title = ttl

        searchQueries = try container.decode([String].self, forKey: .searchQueries)
        visitedSearchResults = try container.decode([VisitedPage].self, forKey: .visitedSearchResults)
        if container.contains(.publicationStatus) {
            publicationStatus = try container.decode(PublicationStatus.self, forKey: .publicationStatus)
        }

        try super.init(from: decoder)
        changePropagationEnabled = false
        warmingUp = true
        defer {
            changePropagationEnabled = true
            warmingUp = false
        }

        self.sign = Self.signPost.createId(object: self)
        if container.contains(.sources) {
            do {
                sources = try container.decode(NoteSources.self, forKey: .sources)
            } catch {
                Logger.shared.logWarning("⚠️ Couldn't decode sources for note id: \(id) - title: \(title)", category: .document)
            }
        }
        setupSourceObserver()

        if let oldType = try? container.decode(NoteType.self, forKey: .type) {
            type = BeamNoteType.fromOldType(oldType, title: ttl, fallbackDate: creationDate)
        } else {
            type = try container.decode(BeamNoteType.self, forKey: .type)
        }
        browsingSessionIds = (try container.decodeIfPresent([UUID].self, forKey: .browsingSessionIds) ?? [UUID]())
        contactId = try? container.decodeIfPresent(UUID.self, forKey: .contactId)
        tombstones = (try? container.decodeIfPresent(Set<UUID>.self, forKey: .tombstones)) ?? tombstones
        switch type {
        case .note:
            break
        case .journal:
            let date = type.journalDate ?? creationDate
            title = BeamDate.journalNoteTitle(for: date)
        }
        open = true
        checkHasNote()
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(searchQueries, forKey: .searchQueries)
        try container.encode(visitedSearchResults, forKey: .visitedSearchResults)
        try container.encode(sources, forKey: .sources)
        try container.encode(publicationStatus, forKey: .publicationStatus)
        try container.encode(browsingSessionIds, forKey: .browsingSessionIds)
        try container.encode(contactId, forKey: .contactId)
        try super.encode(to: encoder)
    }

    public override func deepCopy(withNewId: Bool, selectedElements: [BeamElement]?, includeFoldedChildren: Bool) -> BeamNote? {
        guard let newNote = super.deepCopy(withNewId: withNewId, selectedElements: selectedElements, includeFoldedChildren: includeFoldedChildren) as? BeamNote else {
            return nil
        }

        newNote.databaseId = databaseId
        newNote.title = title
        newNote.creationDate = creationDate
        newNote.updateDate = updateDate
        newNote.type = type
        newNote.version.store(version.load(ordering: .relaxed), ordering: .relaxed)
        newNote.savedVersion = savedVersion
        newNote.publicationStatus = publicationStatus
        if !withNewId { // We don't need to copy the tombstones if we create a separate new note
            newNote.tombstones = tombstones
        }

        return newNote
    }

    public var activeDocumentCancellables = [AnyCancellable]()

    private static func cacheKeyFromTitle(_ title: String) -> String {
        validTitle(fromTitle: title).lowercased()
    }

    private static func cancellableKeyFromNote(_ note: BeamNote) -> UUID {
        note.id
    }

    public static func validTitle(fromTitle title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func getFetchedNote(_ id: UUID) -> BeamNote? {
        fetchedLock.readLock()
        defer { fetchedLock.readUnlock() }

        return Self.fetchedNotes[id]?.ref
    }

    public static func getFetchedNote(_ journalDate: Date) -> BeamNote? {
        getFetchedNote(BeamDate.journalNoteTitle(for: journalDate))
    }

    public func getFetchedNote(_ title: String) -> BeamNote? {
        return Self.getFetchedNote(title)
    }

    public static func getFetchedNote(_ title: String) -> BeamNote? {
        fetchedLock.readLock()
        defer { fetchedLock.readUnlock() }

        guard let uid = Self.fetchedNotesTitles[cacheKeyFromTitle(title)] else { return nil }
        return Self.getFetchedNote(uid)
    }

    public func getFetchedNote(_ id: UUID) -> BeamNote? {
        return Self.getFetchedNote(id)
    }

    public func getFetchedNote(_ journalDate: Date) -> BeamNote? {
        getFetchedNote(BeamDate.journalNoteTitle(for: journalDate))
    }

    static public func visitFetchedNotes(_ visitor: @escaping (BeamNote) -> Void) {
        fetchedLock.readLock()
        defer { fetchedLock.readUnlock() }

        for noteRef in fetchedNotes.values {
            guard let note = noteRef.ref else { continue }
            visitor(note)
        }
    }

    public var pendingSave = ManagedAtomic<Int>(0)

    public static func appendToFetchedNotes(_ note: BeamNote) {
        fetchedLock.writeLock()
        defer { fetchedLock.writeUnlock() }
        fetchedNotes[note.id] = WeakReference<BeamNote>(note)
        fetchedNotesTitles[cacheKeyFromTitle(note.title)] = note.id
        let cancellableKey = cancellableKeyFromNote(note)
        fetchedNotesCancellables.removeValue(forKey: cancellableKey)

        fetchedNotesCancellables[cancellableKey] =
            note.changed
            .receive(on: DispatchQueue.main)
            .sink { [weak note] _ in
                guard let note = note as? BeamNoteDocument else { return }
                note.autoSave()
            }

        fetchedNotes[note.id] = WeakReference(note)
        fetchedNotesTitles[cacheKeyFromTitle(note.title)] = note.id
    }

    public static func clearCancellables() {
        fetchedLock.writeLock()
        defer { fetchedLock.writeUnlock() }

        fetchedNotesCancellables.removeAll()
        fetchedNotes.removeAll()
    }

    public override func childChanged(_ child: BeamElement, _ type: ChangeType) {
        super.childChanged(child, type)
        if var note = note as? BeamNoteDocument {
            note.lastChangedElement = child
        }
    }

    public static func unloadAllNotes() {
        fetchedLock.writeLock()
        defer { fetchedLock.writeUnlock() }

        fetchedNotesCancellables.removeAll()
        fetchedNotes.removeAll()
        fetchedNotesTitles.removeAll()
        clearCancellables()
    }

    public static func unload(note: BeamNote) {
        fetchedLock.writeLock()
        defer { fetchedLock.writeUnlock() }

        fetchedNotesCancellables.removeValue(forKey: cancellableKeyFromNote(note))
        fetchedNotes.removeValue(forKey: note.id)
        fetchedNotesTitles.removeValue(forKey: cacheKeyFromTitle(note.title))
    }

    public static func reloadAfterRename(previousTitle: String, note: BeamNote) {
        fetchedLock.writeLock()
        defer { fetchedLock.writeUnlock() }

        fetchedNotesTitles.removeValue(forKey: cacheKeyFromTitle(previousTitle))
        fetchedNotesTitles[cacheKeyFromTitle(note.title)] = note.id
    }

    // Return true if the note is empty. If the user entered any chars, even just \n, will return false
    public func isEntireNoteEmpty() -> Bool {
        if children.count > 1 { return false }

        if let child = children.first, !child.text.isEmpty || child.children.count > 0 {
            return false
        }

        return true
    }

    public static var indexingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "BeamNoteIndexing"
        queue.maxConcurrentOperationCount = 8
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private static var fetchedNotes: [UUID: WeakReference<BeamNote>] = [:]
    private static var fetchedNotesTitles: [String: UUID] = [:]
    private static var fetchedNotesCancellables: [UUID: Cancellable] = [:]
    private static var fetchedLock = RWLock()

    public func createdByUser() {
        score += 0.1
    }

    public func viewedByUser() {
        score += 0.1
    }

    public func referencedByUser() {
        score += 0.1
    }

    public func modifiedByUser() {
        score += 0.1
    }

    public func importedByUser() {
        score += 0.1
    }

    public override var debugDescription: String {
        return "BeamNode(\(id)) [\(children.count) children]: \(title)"
    }

    public var lock = RWLock()

    public override func readLock() {
        lock.readLock()
    }

    public override func readUnlock() {
        lock.readUnlock()
    }

    public override func writeLock() {
        lock.writeLock()
    }

    public override func writeUnlock() {
        lock.writeUnlock()
    }

    // (Note name, include deleted notes)
    static public var idForNoteNamed: (String, Bool) -> UUID? = { _, _ in
        fatalError()
    }

    // (Note id, include deleted notes)
    static public var titleForNoteId: (UUID, Bool) -> String? = { _, _ in
        fatalError()
    }

    var sourceObserver: Cancellable?
    private func setupSourceObserver() {
        sourceObserver = sources.$changed
            .dropFirst(1)
            .sink { [weak self] _ in self?.change(.meta) }
    }

    public var shouldUpdatePublishedVersion: Bool {
        guard case .published(_, let publicationDate) = publicationStatus else { return false }
        let timeInterval = self.updateDate.timeIntervalSince(publicationDate)
        return timeInterval > 2
    }

    public static var signPost = SignPost("BeamNote")
    public var sign: SignPostId!

    public override func dispatchChildRemoved(_ child: BeamElement) {
        guard changePropagationEnabled else { return }
        guard child.parent != self else { return }
        tombstones.insert(child.id)
    }

    public override func dispatchChildAdded(_ child: BeamElement) {
        guard changePropagationEnabled else { return }
        tombstones.remove(child.id)
    }

}

public func beamCheckMainThread() {
    #if DEBUG
    if !Thread.isMainThread {
        fatalError()
    }
    #endif
}
// swiftlint:enable file_length
