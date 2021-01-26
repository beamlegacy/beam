//
//  BeamNote.swift
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import Combine

struct VisitedPage: Codable, Identifiable {
    var id: UUID = UUID()

    var originalSearchQuery: String
    var url: URL
    var date: Date
    var duration: TimeInterval
}

struct NoteReference: Codable, Equatable {
    var noteName: String
    var elementID: UUID
}

// Document:
class BeamNote: BeamElement {
    @Published var title: String { didSet { change() } }
    @Published var type: NoteType = .note { didSet { change() } }
    @Published public private(set) var outLinks: [String] = [] { didSet { change() } } ///< The links contained in this note
    @Published public private(set) var linkedReferences: [NoteReference] = [] { didSet { change() } } ///< urls of the notes/bullet pointing to this note explicitely
    @Published public private(set) var unlinkedReferences: [NoteReference] = [] { didSet { change() } } ///< urls of the notes/bullet pointing to this note implicitely

    @Published public private(set) var searchQueries: [String] = [] { didSet { change() } } ///< Search queries whose results were used to populate this note
    @Published public private(set) var visitedSearchResults: [VisitedPage] = [] { didSet { change() } } ///< URLs whose content were used to create this note
    @Published public var browsingSessions = [BrowsingTree]() { didSet { change() } }

    override var note: BeamNote? {
        return self
    }

    init(title: String) {
        self.title = title
        super.init()
    }

    enum CodingKeys: String, CodingKey {
        case title
        case type
        case outLinks
        case searchQueries
        case visitedSearchResults
        case browsingSessions
        case linkedReferences
        case unlinkedReferences
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(NoteType.self, forKey: .type)
        outLinks = try container.decode([String].self, forKey: .outLinks)
        searchQueries = try container.decode([String].self, forKey: .searchQueries)
        visitedSearchResults = try container.decode([VisitedPage].self, forKey: .visitedSearchResults)
        if container.contains(.browsingSessions) {
            browsingSessions = try container.decode([BrowsingTree].self, forKey: .browsingSessions)
        }
        if container.contains(.linkedReferences) {
            linkedReferences = try container.decode([NoteReference].self, forKey: .linkedReferences)
        }
        if container.contains(.unlinkedReferences) {
            unlinkedReferences = try container.decode([NoteReference].self, forKey: .unlinkedReferences)
        }

        try super.init(from: decoder)
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(outLinks, forKey: .outLinks)
        try container.encode(searchQueries, forKey: .searchQueries)
        try container.encode(visitedSearchResults, forKey: .visitedSearchResults)
        if !browsingSessions.isEmpty {
            try container.encode(browsingSessions, forKey: .browsingSessions)
        }
        if !linkedReferences.isEmpty {
            try container.encode(linkedReferences, forKey: .linkedReferences)
        }
        if !unlinkedReferences.isEmpty {
            try container.encode(unlinkedReferences, forKey: .unlinkedReferences)
        }

        try super.encode(to: encoder)
    }

    var documentStruct: DocumentStruct? {
        do {
            let encoder = JSONEncoder()
            // Will make conflict and merge easier to know what lines conflicted instead
            // of having all content on a single line to save space
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)

            return DocumentStruct(id: id,
                                  title: title,
                                  createdAt: creationDate,
                                  updatedAt: updateDate,
                                  data: data,
                                  documentType: type == .journal ? .journal : .note)
        } catch {
            Logger.shared.logError("Unable to encode BeamNote into DocumentStruct [\(title) {\(id)}]", category: .document)
            return nil
        }
    }

    func save(documentManager: DocumentManager, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard let documentStruct = documentStruct else {
            Logger.shared.logError("Unable to encode BeamNote into DocumentStruct [\(title) {\(id)}]", category: .document)
            completion?(.success(false))
            return
        }

        documentManager.saveDocument(documentStruct) { result in
            completion?(result)
        }
    }

    var isTodaysNote: Bool { (type == .journal) && (self === AppDelegate.main.data.todaysNote) }

    func addLinkedReference(_ reference: NoteReference) {
        // don't add it twice
        guard !linkedReferences.contains(reference) else { return }
        linkedReferences.append(reference)
    }

    func addUnlinkedReference(_ reference: NoteReference) {
        // don't add it twice
        guard !unlinkedReferences.contains(reference) else { return }
        unlinkedReferences.append(reference)
    }

    private static func instanciateNote(_ documentStruct: DocumentStruct) throws -> BeamNote {
        let decoder = JSONDecoder()
        let note = try decoder.decode(BeamNote.self, from: documentStruct.data)
        note.updateDate = documentStruct.updatedAt
        appendToFetchedNotes(note)
        return note
    }
    static func fetch(_ documentManager: DocumentManager, title: String) -> BeamNote? {
        // Is the note in the cache?
        if let note = fetchedNotes[title] {
            return note
        }

        // Is the note in the document store?
        guard let doc = documentManager.loadDocumentByTitle(title: title) else {
            return nil
        }

//        Logger.shared.logDebug("Note loaded:\n\(String(data: doc.data, encoding: .utf8)!)\n", category: .document)

        do {
            return try instanciateNote(doc)
        } catch {
            Logger.shared.logError("Unable to decode today's note", category: .document)
        }

        return nil
    }

    static func fetchNotesWithType(_ documentManager: DocumentManager, type: DocumentType) -> [BeamNote] {
        return documentManager.loadDocumentsWithType(type: type).compactMap { doc -> BeamNote? in
            if let note = fetchedNotes[doc.title] {
                return note
            }
            do {
                return try instanciateNote(doc)
            } catch {
                Logger.shared.logError("Unable to load document \(doc.title) (\(doc.id))", category: .document)
                return nil
            }
        }
    }

    // Beware that this function crashes whatever note with that title in the cache
    static func create(_ documentManager: DocumentManager, title: String) -> BeamNote {
        assert(fetchedNotes[title] == nil)
        let note = BeamNote(title: title)
        appendToFetchedNotes(note)
        updateNoteCount()
        return note
    }

    static func appendToFetchedNotes(_ note: BeamNote) {
        fetchedNotesCancellables.removeValue(forKey: note.title)
        fetchedNotesCancellables[note.title] =
            note.$changed
            .dropFirst(1)
            .throttle(for: .seconds(2), scheduler: RunLoop.main, latest: false)
            .sink { [weak note] _ in
                let documentManager = DocumentManager()
                note?.detectLinkedNotes(documentManager)
                // TODO: we should only save when changes occured
                note?.save(documentManager: documentManager)
            }
        fetchedNotes[note.title] = note
    }

    static func fetchOrCreate(_ documentManager: DocumentManager, title: String) -> BeamNote {
        // Is the note in the cache?
        if let note = fetch(documentManager, title: title) {
            return note
        }

        // create a new note and add it to the cache
        return create(documentManager, title: title)
    }

    static func unload(note: BeamNote) {
        unload(note: note.title)
    }

    static func unload(note: String) {
        fetchedNotesCancellables.removeValue(forKey: note)
        fetchedNotes.removeValue(forKey: note)
    }

    static func loadAllDocument(_ documentManager: DocumentManager) -> [BeamNote] {
        return documentManager.loadDocuments().compactMap { doc -> BeamNote? in
            if let note = fetchedNotes[doc.title] {
                return note
            }
            do {
                return try instanciateNote(doc)
            } catch {
                Logger.shared.logError("Unable to load document \(doc.title) (\(doc.id))", category: .document)
                return nil
            }
        }
    }

    static func detectLinks(_ documentManager: DocumentManager) {
        let allNotes = Self.loadAllDocument(documentManager)
        for note in allNotes {
            note.detectLinkedNotes(documentManager)
            note.connectUnlinkedNotes(note.title, allNotes)
        }
    }

    private static var fetchedNotes: [String: BeamNote] = [:]
    private static var fetchedNotesCancellables: [String: Cancellable] = [:]

    private static func updateNoteCount() {
        AppDelegate.main.data.updateNoteCount()
    }

    func createdByUser() {
        score += 0.1
    }

    func viewedByUser() {
        score += 0.1
    }

    func referencedByUser() {
        score += 0.1
    }

    func modifiedByUser() {
        score += 0.1
    }

    func importedByUser() {
        score += 0.1
    }
}
