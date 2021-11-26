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
    func observeDocumentChange()
    func autoSave()
    var lastChangedElement: BeamElement? { get set }
}

public enum BeamNoteError: Error, Equatable {
    case saveAlreadyRunning
    case unableToCreateDocumentStruct
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

    @Published public var searchQueries: [String] = [] { didSet { change(.meta) } } ///< Search queries whose results were used to populate this note
    @Published public var visitedSearchResults: [VisitedPage] = [] { didSet { change(.meta) } } ///< URLs whose content were used to create this note
    public var browsingSessionIds = [UUID]() { didSet { change(.meta) } }
    public var sources = NoteSources()
    @Published public var version = ManagedAtomic<Int64>(0)
    @Published public var savedVersion = ManagedAtomic<Int64>(0)
    public var databaseId: UUID?
    @Published public var deleted: Bool = false
    @Published public var saving = ManagedAtomic<Bool>(false)
    @Published public var updateAttempts: Int = 0
    @Published public var updates: Int = 0

    public var titleAndId: String {
        "\(title) {\(id)} v\(version)"
    }

    public override var note: BeamNote? {
        return self
    }

    public override func checkHasNote() {
        hasNote = true
    }

    public init(title: String) {
        self.title = Self.validTitle(fromTitle: title)
        super.init()
        setupSourceObserver()
        checkHasNote()
    }

    public init(journalDate: Date) {
        self.title = BeamDate.journalNoteTitle(for: journalDate)
        self.type = BeamNoteType.journalForDate(journalDate)
        super.init()
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
        switch type {
        case .note:
            break
        case .journal:
            let date = type.journalDate ?? creationDate
            title = BeamDate.journalNoteTitle(for: date)
        }
        open = true
        checkHasNote()

        #if DEBUG
        let count = (Self.decodeCount[id] ?? 0) + 1
        Self.decodeCount[id] = count
        //swiftlint:disable print
        print("Decoded \(ttl) - \(id) (count = \(count))")
        //swiftlint:enable print
        #endif
    }

    #if DEBUG
    static var decodeCount = [UUID: Int]()
    #endif

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(searchQueries, forKey: .searchQueries)
        try container.encode(visitedSearchResults, forKey: .visitedSearchResults)
        try container.encode(sources, forKey: .sources)
        try container.encode(publicationStatus, forKey: .publicationStatus)
        try container.encode(browsingSessionIds, forKey: .browsingSessionIds)
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

        return newNote
    }

    public var activeDocumentCancellables = [AnyCancellable]()
    public func merge(other: BeamNote) {
        var oldElems = [UUID: BeamElement]()
        for e in flatElements {
            oldElems[e.id] = e
        }

        var newElems = [UUID: BeamElement]()
        for e in other.flatElements {
            newElems[e.id] = e
        }

        for (uuid, element) in newElems {
            if let oldElement = oldElems[uuid] {
                oldElement.text = element.text
            }
        }
    }

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
        beamCheckMainThread()
        return Self.fetchedNotes[id]?.ref
    }

    public func getFetchedNote(_ title: String) -> BeamNote? {
        beamCheckMainThread()
        return Self.getFetchedNote(title)
    }

    public static func getFetchedNote(_ title: String) -> BeamNote? {
        beamCheckMainThread()
        guard let uid = Self.fetchedNotesTitles[title] else { return nil }
        return Self.getFetchedNote(uid)
    }

    public func getFetchedNote(_ id: UUID) -> BeamNote? {
        beamCheckMainThread()
        return Self.getFetchedNote(id)
    }

    public var pendingSave = ManagedAtomic<Int>(0)

    public static func appendToFetchedNotes(_ note: BeamNote) {
        beamCheckMainThread()
        fetchedNotes[note.id] = WeakReference<BeamNote>(note)
        fetchedNotesTitles[note.title] = note.id
        let cancellableKey = cancellableKeyFromNote(note)
        fetchedNotesCancellables.removeValue(forKey: cancellableKey)

        fetchedNotesCancellables[cancellableKey] =
            note.changed
            .dropFirst(1)
            .receive(on: DispatchQueue.main)
            .sink { [weak note] _ in
                guard let note = note as? BeamNoteDocument else { return }
                note.autoSave()
            }
        if let note = note as? BeamNoteDocument {
            note.observeDocumentChange()
        }

        fetchedNotes[note.id] = WeakReference(note)
        fetchedNotesTitles[note.title] = note.id
    }

    public static func clearCancellables() {
        fetchedNotesCancellables.removeAll()
        fetchedNotes.removeAll()
    }

    public override func childChanged(_ child: BeamElement, _ type: ChangeType) {
        super.childChanged(child, type)
        if var note = note as? BeamNoteDocument {
            note.lastChangedElement = child
        }
    }

    public static func unload(note: BeamNote) {
        beamCheckMainThread()
        fetchedNotesCancellables.removeValue(forKey: cancellableKeyFromNote(note))
        fetchedNotes.removeValue(forKey: note.id)
        fetchedNotesTitles.removeValue(forKey: note.title)
    }

    public static func reloadAfterRename(previousTitle: String, note: BeamNote) {
        beamCheckMainThread()
        fetchedNotesTitles.removeValue(forKey: cacheKeyFromTitle(previousTitle))
        fetchedNotesTitles[cacheKeyFromTitle(note.title)] = note.id
    }

    // Return true if the note is empty. If the user entered any chars, even just \n, will return false
    public func isEntireNoteEmpty() -> Bool {
        if children.count > 1 { return false }

        if let child = children.first, !child.text.isEmpty || children.count > 1 {
            return false
        }

        return true
    }

    public static var indexingQueue = DispatchQueue(label: "BeamNoteIndexing")
    public private(set) static var fetchedNotes: [UUID: WeakReference<BeamNote>] = [:]
    public private(set) static var fetchedNotesTitles: [String: UUID] = [:]
    private static var fetchedNotesCancellables: [UUID: Cancellable] = [:]

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
}

public func beamCheckMainThread() {
    #if DEBUG
    if !Thread.isMainThread {
        fatalError()
    }
    #endif
}
// swiftlint:enable file_length
