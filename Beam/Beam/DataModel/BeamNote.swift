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
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(NoteType.self, forKey: .type)
        outLinks = try container.decode([String].self, forKey: .outLinks)
        searchQueries = try container.decode([String].self, forKey: .searchQueries)
        visitedSearchResults = try container.decode([VisitedPage].self, forKey: .visitedSearchResults)

        try super.init(from: decoder)
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(outLinks, forKey: .outLinks)
        try container.encode(searchQueries, forKey: .searchQueries)
        try container.encode(visitedSearchResults, forKey: .visitedSearchResults)

        try super.encode(to: encoder)
    }

    func save(documentManager: DocumentManager, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        do {
            let encoder = JSONEncoder()
            #if DEBUG
            encoder.outputFormatting = .prettyPrinted
            #endif
            let data = try encoder.encode(self)
//            let str = String(data: data, encoding: .utf8)
//            print(str!)

            guard let documentStruct = DocumentStruct(id: id, title: title, data: data, documentType: type == .journal ? .journal : .note) else {
                completion?(.success(false))
                return
            }

            documentManager.saveDocument(documentStruct) { result in
                completion?(result)
            }
        } catch {
            completion?(.failure(error))
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
        fetchedNotes[documentStruct.title] = note
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

        #if DEBUG
        Logger.shared.logInfo("Note loaded:\n\(String(data: doc.data, encoding: .utf8)!)\n", category: .document)
        #endif
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
        let note = BeamNote(title: title)
        fetchedNotes[title] = note
        updateNoteCount()
        return note
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

    static func detectUnlinkedNotes(_ documentManager: DocumentManager) {
        let allNotes = Self.loadAllDocument(documentManager)
        for note in allNotes {
            note.connectUnlinkedNotes(note.title, allNotes)
        }

    }

    private static var fetchedNotes: [String: BeamNote] = [:]

    private static func updateNoteCount() {
        AppDelegate.main.data.updateNoteCount()
    }
}

// TODO: Remove this when we remove Note/Bullet from the build
// temp adapter
func beamNoteFrom(note: Note) -> BeamNote {
    let n = BeamNote(title: note.title)

    for b in note.rootBullets() {
        n.addChild(beamElementFrom(bullet: b))
    }

    return n
}

func beamElementFrom(bullet: Bullet) -> BeamElement {
    let element = BeamElement()
    element.text = bullet.content

    for b in bullet.sortedChildren() {
        element.addChild(beamElementFrom(bullet: b))
    }

    return element
}
