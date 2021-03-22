//
//  BeamNote.swift
//
//  Created by Sebastien Metrot on 18/09/2020.
//
// swiftlint:disable file_length

import Foundation
import Combine

enum BeamNoteError: Error, Equatable {
    case saveAlreadyRunning
    case unableToCreateDocumentStruct
}

struct VisitedPage: Codable, Identifiable {
    var id: UUID = UUID()

    var originalSearchQuery: String
    var url: URL
    var date: Date
    var duration: TimeInterval
}

struct NoteReference: Codable, Equatable, Hashable {
    var noteTitle: String
    var elementID: UUID
}

// Document:
class BeamNote: BeamElement {
    @Published var title: String { didSet { change(.text) } }
    @Published var type: NoteType = .note { didSet { change(.meta) } }
    @Published public private(set) var references: [NoteReference] = [] { didSet { change(.meta) } } ///< urls of the notes/bullet pointing to this note

    @Published public private(set) var searchQueries: [String] = [] { didSet { change(.meta) } } ///< Search queries whose results were used to populate this note
    @Published public private(set) var visitedSearchResults: [VisitedPage] = [] { didSet { change(.meta) } } ///< URLs whose content were used to create this note
    @Published public var browsingSessions = [BrowsingTree]() { didSet { change(.meta) } }
    private var version: Int64 = 0
    private var savedVersion: Int64 = 0

    override var note: BeamNote? {
        return self
    }

    var cmdManager = CommandManager<Widget>()

    init(title: String) {
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

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(NoteType.self, forKey: .type)
        searchQueries = try container.decode([String].self, forKey: .searchQueries)
        visitedSearchResults = try container.decode([VisitedPage].self, forKey: .visitedSearchResults)
        if container.contains(.browsingSessions) {
            browsingSessions = try container.decode([BrowsingTree].self, forKey: .browsingSessions)
        }

        var refs = [NoteReference]()
        // old references
        if container.contains(.linkedReferences) {
            refs += try container.decode([NoteReference].self, forKey: .linkedReferences)
        }
        if container.contains(.unlinkedReferences) {
            refs += try container.decode([NoteReference].self, forKey: .unlinkedReferences)
        }
        // new (unified) references
        if container.contains(.references) {
            refs += try container.decode([NoteReference].self, forKey: .references)
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

    var documentStruct: DocumentStruct? {
        do {
            let encoder = JSONEncoder()
            // Will make conflict and merge easier to know what lines conflicted instead
            // of having all content on a single line to save space
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)

            return DocumentStruct(id: id,
                                  title: title.lowercased(),
                                  createdAt: creationDate,
                                  updatedAt: updateDate,
                                  data: data,
                                  documentType: type == .journal ? .journal : .note,
                                  version: version)
        } catch {
            Logger.shared.logError("Unable to encode BeamNote into DocumentStruct [\(title) {\(id)}]", category: .document)
            return nil
        }
    }
    private var activeDocumentCancellable: AnyCancellable?
    private func observeDocumentChange(documentManager: DocumentManager) {
        guard activeDocumentCancellable == nil else { return }
        guard let docStruct = documentStruct else { return }

        Logger.shared.logInfo("Observe changes for note \(title)", category: .document)
        activeDocumentCancellable = documentManager.onDocumentChange(docStruct) { [unowned self] docStruct in
            DispatchQueue.main.async {
                // reload self
                guard self.version < docStruct.version else {
                    //                Logger.shared.logDebug("BeamNote \(self.title) observer skipped version \(docStruct.version) (must be greater than current \(self.version))")
                    return
                }

                changePropagationEnabled = false
                defer {
                    changePropagationEnabled = true
                }

                let decoder = JSONDecoder()
                guard let newSelf = try? decoder.decode(BeamNote.self, from: docStruct.data) else {
                    Logger.shared.logError("Unable to decode new documentStruct \(docStruct.title)",
                                           category: .document)
                    return
                }

                self.title = newSelf.title
                self.type = newSelf.type
                self.searchQueries = newSelf.searchQueries
                self.visitedSearchResults = newSelf.visitedSearchResults
                self.browsingSessions = newSelf.browsingSessions
                self.version = docStruct.version
                self.savedVersion = self.version
                recursiveUpdate(other: newSelf)
            }
        }
    }

    func merge(other: BeamNote) {
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

    func save(documentManager: DocumentManager, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard version == savedVersion else {
            Logger.shared.logError("Still wating for the result from the last save [\(title) {\(id)} - saved version \(savedVersion) / current \(version)]", category: .document)
            completion?(.failure(BeamNoteError.saveAlreadyRunning))
            return
        }
        guard let documentStruct = documentStruct else {
            Logger.shared.logError("Unable to find active document struct [\(title) {\(id)}]", category: .document)
            completion?(.failure(BeamNoteError.unableToCreateDocumentStruct))
            return
        }

        Logger.shared.logInfo("BeamNote wants to save: \(title)", category: .document)
        let newDoc = documentManager.saveDocument(documentStruct, completion: { [weak self] result in
            if let self = self {
                switch result {
                case .success(true):
                    self.savedVersion = self.version
                    self.pendingSave = 0

                case .failure(BeamNoteError.saveAlreadyRunning):
                    self.pendingSave += 1

                default:
                    self.version = self.savedVersion
                    Logger.shared.logError("Saving note \(self.title) failed", category: .document)
                    if self.pendingSave > 0 {
                        Logger.shared.logDebug("Trying again: Saving note \(self.title) as there were \(self.pendingSave) pending save operations", category: .document)
                        self.save(documentManager: documentManager, completion: completion)
                    }
                }
            }
            completion?(result)
        })
        version = newDoc.version
    }

    var isTodaysNote: Bool { (type == .journal) && (self === AppDelegate.main.data.todaysNote) }

    func addReference(_ reference: NoteReference) {
        // don't add it twice
        guard !references.contains(reference) else { return }
        references.append(reference)
    }

    func removeReference(_ reference: NoteReference) {
        references.removeAll(where: { ref -> Bool in
            ref == reference
        })
    }

    func removeAllReferences() {
        references = []
    }

    static private func getFetchedNote(_ title: String) -> BeamNote? {
        return Self.fetchedNotes[title.lowercased()]?.ref
    }

    private func getFetchedNote(_ title: String) -> BeamNote? {
        return Self.getFetchedNote(title)
    }

    private static func instanciateNote(_ documentManager: DocumentManager, _ documentStruct: DocumentStruct, keepInMemory: Bool = true) throws -> BeamNote {
        let decoder = JSONDecoder()
        let note = try decoder.decode(BeamNote.self, from: documentStruct.data)
        note.version = documentStruct.version
        note.savedVersion = note.version
        note.updateDate = documentStruct.updatedAt
        if keepInMemory {
            appendToFetchedNotes(note)
        }
        return note
    }

    static func fetch(_ documentManager: DocumentManager, title: String) -> BeamNote? {
        // Is the note in the cache?
        if let note = getFetchedNote(title) {
            return note
        }

        // Is the note in the document store?
        guard let doc = documentManager.loadDocumentByTitle(title: title.lowercased()) else {
            return nil
        }

//        Logger.shared.logDebug("Note loaded:\n\(String(data: doc.data, encoding: .utf8)!)\n", category: .document)

        do {
            return try instanciateNote(documentManager, doc)
        } catch {
            Logger.shared.logError("Unable to decode today's note", category: .document)
        }

        return nil
    }

    static func fetchNotesWithType(_ documentManager: DocumentManager, type: DocumentType, _ limit: Int, _ fetchOffset: Int) -> [BeamNote] {
        return documentManager.loadDocumentsWithType(type: type, limit, fetchOffset).compactMap { doc -> BeamNote? in
            if let note = getFetchedNote(doc.title) {
                return note
            }
            do {
                return try instanciateNote(documentManager, doc)
            } catch {
                Logger.shared.logError("Unable to load document \(doc.title) (\(doc.id))", category: .document)
                return nil
            }
        }
    }

    // Beware that this function crashes whatever note with that title in the cache
    static func create(_ documentManager: DocumentManager, title: String) -> BeamNote {
        assert(getFetchedNote(title) == nil)
        let note = BeamNote(title: title)
        appendToFetchedNotes(note)
        updateNoteCount()
        return note
    }

    var pendingSave: Int = 0

    static func appendToFetchedNotes(_ note: BeamNote) {
        fetchedNotes[note.title.lowercased()] = WeakReference<BeamNote>(note)
        fetchedNotesCancellables.removeValue(forKey: note.title)

        fetchedNotesCancellables[note.title] =
            note.$changed
            .dropFirst(1)

//            .debounce(for: .seconds(2), scheduler: RunLoop.main)
//            .throttle(for: .seconds(2), scheduler: RunLoop.main, latest: false)
            .receive(on: DispatchQueue.main)
            .sink { [weak note] change in
                guard let note = note else { return }
                AppDelegate.main.data.noteAutoSaveService.addNoteToSave(note, change?.1 == .text)
            }
        note.observeDocumentChange(documentManager: AppDelegate.main.data.documentManager)

        fetchedNotes[note.title.lowercased()] = WeakReference(note)
    }

    static func clearCancellables() {
        fetchedNotesCancellables.removeAll()
        fetchedNotes.removeAll()
    }

    override func childChanged(_ child: BeamElement, _ type: ChangeType) {
        super.childChanged(child, type)
        AppDelegate.main.data.lastChangedElement = child
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

    func isEntireNoteEmpty() -> Bool {
        guard let child = children.first,
              child.text.isEmpty && children.count == 1 else {
            return false
        }
        return true
    }

    static var linkDetectionQueue = DispatchQueue(label: "LinkDetector")
    static var linkDetectionRunning = false
    static func requestLinkDetection(for noteTitled: String? = nil) {
        guard !linkDetectionRunning else { return }
        linkDetectionRunning = true

        linkDetectionQueue.async {
            detectLinks(for: noteTitled)
            DispatchQueue.main.async {
                linkDetectionRunning = false
            }
        }
    }

    static func detectLinks(in noteTitle: String, to allNotes: [String], with documentManager: DocumentManager) {
        guard let doc = documentManager.loadDocByTitleInBg(title: noteTitle.lowercased()) else {
            return
        }

        do {
            let note = try instanciateNote(documentManager, doc, keepInMemory: false)

            // Detect Linked Notes
            note.detectLinkedNotes(documentManager, async: true)

            // remove broken linked references
            let brokenLinks = note.getBrokenLinkedReferences(documentManager, allNotes)

            // remove broken unlinked references
            let brokenRefs = note.getBrokenUnlinkedReferences(documentManager, allNotes)

            // Detect UnLinked Notes
            let unlinks = note.getDeepUnlinkedReferences(noteTitle, allNotes)
            DispatchQueue.main.async {
                let note = BeamNote.fetch(documentManager, title: noteTitle)

                for brokenLink in brokenLinks {
                    note?.removeReference(brokenLink)
                }

                for brokenRef in brokenRefs {
                    note?.removeReference(brokenRef)
                }

                for (name, refs) in unlinks {
                    let referencedNote = BeamNote.fetch(documentManager, title: name)
                    for ref in refs {
                        referencedNote?.addReference(ref)
                    }
                }
            }
        } catch {
            Logger.shared.logError("LinkDetection: Unable to decode note \(doc.title)", category: .document)
        }
    }

    static func detectLinks(for noteTitled: String? = nil) {
        let documentManager = DocumentManager()
        let allNotes = documentManager.allDocumentsTitles()
        let allTitles = noteTitled == nil ? allNotes : [noteTitled!]
        Logger.shared.logInfo("Detect links for \(allTitles.count) notes", category: .document)

        for title in allNotes {
            detectLinks(in: title, to: allTitles, with: documentManager)
        }
    }

    func getBrokenLinkedReferences(_ documentManager: DocumentManager, _ allNotes: [String]) -> [NoteReference] {
        var broken = [NoteReference]()
        var notes = [String: BeamNote]()
        for link in references {
            guard let note: BeamNote = {
                notes[link.noteTitle] ?? {
                    guard let doc = documentManager.loadDocumentByTitle(title: link.noteTitle.lowercased()) else {
                        return nil
                    }

                    do {
                        let note = try Self.instanciateNote(documentManager, doc, keepInMemory: false)
                        notes[note.title] = note
                        return note
                    } catch {
                        Logger.shared.logError("LinkReference verification: Unable to decode note \(doc.title)", category: .document)
                    }
                    return nil
                }()
            }() else {
                continue
            }

            guard let element = note.findElement(link.elementID),
                  element.hasLinkToNote(named: title)
            else { broken.append(link); continue }
        }

        return broken
    }

    func getBrokenUnlinkedReferences(_ documentManager: DocumentManager, _ allNotes: [String]) -> [NoteReference] {
        var broken = [NoteReference]()
        var notes = [String: BeamNote]()
        for ref in references {
            guard let note: BeamNote = {
                notes[ref.noteTitle] ?? {
                    guard let doc = documentManager.loadDocumentByTitle(title: ref.noteTitle.lowercased()) else {
                        return nil
                    }

                    do {
                        let note = try Self.instanciateNote(documentManager, doc, keepInMemory: false)
                        notes[note.title] = note
                        return note
                    } catch {
                        Logger.shared.logError("UnlinkReference verification: Unable to decode note \(doc.title)", category: .document)
                    }
                    return nil
                }()
            }() else {
                continue
            }

            guard let element = note.findElement(ref.elementID),
                  let refs = element.getUnlinkedReferences(note.title, allNotes)[title],
                  refs.contains(ref)
            else {
                broken.append(ref)
                continue
            }
        }

        return broken
    }

    public private(set) static var fetchedNotes: [String: WeakReference<BeamNote>] = [:]
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

    public override var debugDescription: String {
        return "BeamNode(\(id)) [\(children.count) children]: \(title)"
    }

    var lock = RWLock()

    override func readLock() {
        lock.readLock()
    }

    override func readUnlock() {
        lock.readUnlock()
    }

    override func writeLock() {
        lock.writeLock()
    }

    override func writeUnlock() {
        lock.writeUnlock()
    }
}

// swiftlint:enable file_length
