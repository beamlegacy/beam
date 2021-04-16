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

        try super.encode(to: encoder)
    }

    /// Carefull this isn't a proper deepCopy
    /// BrowsingSessions contains BrowsingNode that are not properly cloned.
    /// This is used and needed for copy&paste atm
    public override func deepCopy(withNewId: Bool, selectedElements: [BeamElement]?) -> BeamNote {
        let note = BeamNote(title: title)
        note.type = type
        note.searchQueries = searchQueries
        note.visitedSearchResults = visitedSearchResults
        note.text = text
        note.open = open
        note.readOnly = readOnly
        note.score = score
        note.creationDate = creationDate
        note.kind = kind
        note.childrenFormat = childrenFormat
        note.query = query
        if !browsingSessions.isEmpty {
            for browsingSession in browsingSessions {
                note.browsingSessions.append(browsingSession.deepCopy())
            }
        }
        if !references.isEmpty {
            note.references = references
        }
        for child in children {
            if let isSelected = selectedElements?.contains(child), isSelected {
                note.children.append(child.deepCopy(withNewId: withNewId, selectedElements: selectedElements))
            } else {
                note.children.append(contentsOf: child.deepCopy(withNewId: withNewId, selectedElements: selectedElements).children)
            }
        }
        return note
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
