//
//  BeamNote.swift
//
//  Created by Sebastien Metrot on 18/09/2020.
//
// swiftlint:disable file_length

import Foundation
import Combine

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

// Document:
public class BeamNote: BeamElement {
    @Published public var title: String { didSet { change(.text) } }
    @Published public var type: BeamNoteType = .note { didSet { change(.meta) } }
    @Published public var isPublic: Bool = false

    @Published public var searchQueries: [String] = [] { didSet { change(.meta) } } ///< Search queries whose results were used to populate this note
    @Published public var visitedSearchResults: [VisitedPage] = [] { didSet { change(.meta) } } ///< URLs whose content were used to create this note
    @Published public var browsingSessions = [BrowsingTree]() { didSet { change(.meta) } }
    public var sources = NoteSources()
    public var version: Int64 = 0
    public var savedVersion: Int64 = 0
    public var databaseId: UUID?
    @Published public var deleted: Bool = false

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
        case browsingSessions
        case sources
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let ttl = try container.decode(String.self, forKey: .title)
        title = ttl

        searchQueries = try container.decode([String].self, forKey: .searchQueries)
        visitedSearchResults = try container.decode([VisitedPage].self, forKey: .visitedSearchResults)
        if container.contains(.browsingSessions) {
            browsingSessions = try container.decode([BrowsingTree].self, forKey: .browsingSessions)
        }
        try super.init(from: decoder)
        if container.contains(.sources) {
            sources = try container.decode(NoteSources.self, forKey: .sources)
            setupSourceObserver()
        }

        if let oldType = try? container.decode(NoteType.self, forKey: .type) {
            type = BeamNoteType.fromOldType(oldType, title: ttl, fallbackDate: creationDate)
        } else {
            type = try container.decode(BeamNoteType.self, forKey: .type)
        }

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
        if !browsingSessions.isEmpty {
            try container.encode(browsingSessions, forKey: .browsingSessions)
        }
        try container.encode(sources, forKey: .sources)
        try super.encode(to: encoder)
    }

    public override func deepCopy(withNewId: Bool, selectedElements: [BeamElement]?) -> BeamNote? {
        guard let newNote = super.deepCopy(withNewId: withNewId, selectedElements: selectedElements) as? BeamNote else {
            return nil
        }

        newNote.databaseId = databaseId
        newNote.title = title
        newNote.creationDate = creationDate
        newNote.updateDate = updateDate
        newNote.type = type
        newNote.version = version
        newNote.savedVersion = savedVersion
        newNote.isPublic = isPublic

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
        return Self.fetchedNotes.first(where: { (_, value: WeakReference<BeamNote>) in
            value.ref?.id == id
        })?.value.ref
    }

    public func getFetchedNote(_ title: String) -> BeamNote? {
        return Self.getFetchedNote(title)
    }

    public static func getFetchedNote(_ title: String) -> BeamNote? {
        return Self.fetchedNotes[cacheKeyFromTitle(title)]?.ref
    }

    public func getFetchedNote(_ id: UUID) -> BeamNote? {
        return Self.getFetchedNote(id)
    }

    public var pendingSave: Int = 0

    public static func appendToFetchedNotes(_ note: BeamNote) {
        fetchedNotes[cacheKeyFromTitle(note.title)] = WeakReference<BeamNote>(note)
        let cancellableKey = cancellableKeyFromNote(note)
        fetchedNotesCancellables.removeValue(forKey: cancellableKey)

        fetchedNotesCancellables[cancellableKey] =
            note.$changed
            .dropFirst(1)
            .receive(on: DispatchQueue.main)
            .sink { [weak note] _ in
                guard let note = note as? BeamNoteDocument else { return }
                note.autoSave()
            }
        if let note = note as? BeamNoteDocument {
            note.observeDocumentChange()
        }

        fetchedNotes[cacheKeyFromTitle(note.title)] = WeakReference(note)
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
        fetchedNotesCancellables.removeValue(forKey: cancellableKeyFromNote(note))
        fetchedNotes.removeValue(forKey: cacheKeyFromTitle(note.title))
    }

    public static func reloadAfterRename(previousTitle: String, note: BeamNote) {
        fetchedNotes.removeValue(forKey: cacheKeyFromTitle(previousTitle))
        fetchedNotes[cacheKeyFromTitle(note.title)] = WeakReference(note)
    }

    public func isEntireNoteEmpty() -> Bool {
        guard let child = children.first,
              child.text.isEmpty && children.count == 1 else {
            return false
        }
        return true
    }

    public static var indexingQueue = DispatchQueue(label: "BeamNoteIndexing")
    public private(set) static var fetchedNotes: [String: WeakReference<BeamNote>] = [:]
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
}

// swiftlint:enable file_length
