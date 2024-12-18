//
//  BeamNoteCollectionWrapper.swift
//  Beam
//
//  Created by Sebastien Metrot on 07/04/2022.
//

import BeamCore

/// A representation of a collection of note documents written to disk when exported by the application.
final class BeamNoteCollectionWrapper: NSDocument {
    var data: BeamData? {
        didSet {
            noteDocuments.forEach { $0.data = data }
        }
    }
    private(set) var noteDocuments = Set<BeamNoteDocumentWrapper>()

    init(fileWrapper: FileWrapper, data: BeamData?) throws {
        super.init()
        try read(from: fileWrapper, ofType: Self.documentTypeName)
    }

    init(notes: [BeamNote], data: BeamData?) {
        // Make sure we don't have duplicates
        self.data = data
        let noteset = Set<BeamNote>(notes)
        for note in noteset {
            noteDocuments.insert(BeamNoteDocumentWrapper(note: note, data: data))
        }
        super.init()
    }

    override init() {
        guard let collection = BeamData.shared.currentDocumentCollection else { super.init(); return }
        for id in (try? collection.fetchIds(filters: [])) ?? [] {
            guard let note = BeamNote.fetch(id: id) else { continue }
            noteDocuments.insert(BeamNoteDocumentWrapper(note: note, data: nil))
        }
        super.init()
    }

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        let rootWrapper = FileWrapper(directoryWithFileWrappers: [:])

        for doc in noteDocuments {
            guard let wrapper = try? doc.fileWrapper(ofType: BeamNoteDocumentWrapper.documentTypeName)
            else {
                Logger.shared.logError("Error while exporting \(doc.note?.titleAndId ?? "<nil note>")", category: .document)
                continue
            }
            rootWrapper.addFileWrapper(wrapper)
        }

        return rootWrapper
    }

    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        guard let fileWrappers = fileWrapper.fileWrappers else {
            Logger.shared.logError("Empty note collection \(String(describing: fileWrapper.filename))", category: .document)
            return
        }
        for fileWrapper in fileWrappers.values {
            guard let docWrapper = try? BeamNoteDocumentWrapper(fileWrapper: fileWrapper, data: data) else {
                Logger.shared.logError("Unable to open document \(String(describing: fileWrapper.filename))", category: .document)
                continue
            }

            noteDocuments.insert(docWrapper)
        }
    }

    func importNotes() throws {
        for document in noteDocuments {
            try document.importNote()
        }
    }

    static let fileExtension = "beamCollection"
    static let documentTypeName = "co.beamapp.noteCollection"

    static var preferredFilename: String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
        let dateString = dateFormatter.string(from: BeamDate.now)
        return "BeamExport-\(dateString).\(fileExtension)"
    }

    enum Error: Swift.Error {
        case incompleteNoteDocument
    }
}
