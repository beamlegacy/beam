//
//  BeamNote.swift
//
//  Created by Sebastien Metrot on 18/09/2020.
//
// swiftlint:disable file_length

import Foundation
import Combine

public enum NoteType: String, Codable {
    case journal
    case note
}

public protocol BeamNoteDocument {
    func observeDocumentChange()
    func autoSave(_ relink: Bool)
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
    public var noteTitle: String
    public var elementID: UUID

    public init(noteTitle: String, elementID: UUID) {
        self.noteTitle = noteTitle
        self.elementID = elementID
    }
}

// Document:
public class BeamNote: BeamElement {
    @Published public var title: String { didSet { change(.text) } }
    @Published public var type: NoteType = .note { didSet { change(.meta) } }
    @Published public var isPublic: Bool = false

    @Published public private(set) var references: [BeamNoteReference] = [] { didSet { change(.meta) } } ///< urls of the notes/bullet pointing to this note

    @Published public var searchQueries: [String] = [] { didSet { change(.meta) } } ///< Search queries whose results were used to populate this note
    @Published public var visitedSearchResults: [VisitedPage] = [] { didSet { change(.meta) } } ///< URLs whose content were used to create this note
    @Published public var browsingSessions = [BrowsingTree]() { didSet { change(.meta) } }
    public var version: Int64 = 0
    public var savedVersion: Int64 = 0

    public override var note: BeamNote? {
        return self
    }

    public init(title: String) {
        self.title = title
        super.init()
    }

    enum CodingKeys: String, CodingKey {
        case title
        case type
        case searchQueries
        case visitedSearchResults
        case browsingSessions
        case linkedReferences
        case unlinkedReferences
        case references
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(NoteType.self, forKey: .type)
        searchQueries = try container.decode([String].self, forKey: .searchQueries)
        visitedSearchResults = try container.decode([VisitedPage].self, forKey: .visitedSearchResults)
        if container.contains(.browsingSessions) {
            browsingSessions = try container.decode([BrowsingTree].self, forKey: .browsingSessions)
        }

        var refs = [BeamNoteReference]()
        // old references
        if container.contains(.linkedReferences) {
            refs += (try? container.decode([BeamNoteReference].self, forKey: .linkedReferences)) ?? []
        }
        if container.contains(.unlinkedReferences) {
            refs += (try? container.decode([BeamNoteReference].self, forKey: .unlinkedReferences)) ?? []
        }
        // new (unified) references
        if container.contains(.references) {
            refs += (try? container.decode([BeamNoteReference].self, forKey: .references)) ?? []
        }

        references = refs

        try super.init(from: decoder)
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
        if !references.isEmpty {
            try container.encode(references, forKey: .references)
        }

        try super.encode(to: encoder)
    }

    public var activeDocumentCancellable: AnyCancellable?
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

    public func addReference(_ reference: BeamNoteReference) {
        // don't add it twice
        guard !references.contains(reference) else { return }
        references.append(reference)
    }

    public func removeReference(_ reference: BeamNoteReference) {
        references.removeAll(where: { ref -> Bool in
            ref == reference
        })
    }

    public func removeAllReferences() {
        references = []
    }

    public static func getFetchedNote(_ title: String) -> BeamNote? {
        return Self.fetchedNotes[title.lowercased()]?.ref
    }

    public func getFetchedNote(_ title: String) -> BeamNote? {
        return Self.getFetchedNote(title)
    }

    public var pendingSave: Int = 0

    public static func appendToFetchedNotes(_ note: BeamNote) {
        fetchedNotes[note.title.lowercased()] = WeakReference<BeamNote>(note)
        fetchedNotesCancellables.removeValue(forKey: note.title)

        fetchedNotesCancellables[note.title] =
            note.$changed
            .dropFirst(1)

//            .debounce(for: .seconds(2), scheduler: RunLoop.main)
//            .throttle(for: .seconds(2), scheduler: RunLoop.main, latest: false)
            .receive(on: DispatchQueue.main)
            .sink { [weak note] change in
                guard let note = note as? BeamNoteDocument else { return }
                note.autoSave(change?.1 == .text)
            }
        if let note = note as? BeamNoteDocument {
            note.observeDocumentChange()
        }

        fetchedNotes[note.title.lowercased()] = WeakReference(note)
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
        unload(note: note.title)
    }

    public static func unload(note: String) {
        fetchedNotesCancellables.removeValue(forKey: note)
        fetchedNotes.removeValue(forKey: note)
    }

    public func isEntireNoteEmpty() -> Bool {
        guard let child = children.first,
              child.text.isEmpty && children.count == 1 else {
            return false
        }
        return true
    }

    public static var linkDetectionQueue = DispatchQueue(label: "LinkDetector")
    public static var linkDetectionRunning = false
    public private(set) static var fetchedNotes: [String: WeakReference<BeamNote>] = [:]
    private static var fetchedNotesCancellables: [String: Cancellable] = [:]

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
}

// swiftlint:enable file_length
