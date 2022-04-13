//
//  BeamNoteDocumentWrapper.swift
//  Beam
//
//  Created by Sebastien Metrot on 04/04/2022.
//

import Foundation
import BeamCore

/// A representation of the note document written to disk when exported by the application.
final class BeamNoteDocumentWrapper: NSDocument {
    private(set) var note: BeamNote?
    struct File {
        var id: UUID
        var name: String
        var data: Data
    }

    private var files = [String: File]()

    init(fileWrapper: FileWrapper) throws {
        super.init()
        try read(from: fileWrapper, ofType: Self.documentTypeName)
    }

    init(note: BeamNote) {
        self.note = note

        for (fileId, _) in note.allFileElements {
            guard let file = try? BeamFileDBManager.shared.fetch(uid: fileId) else { continue }
            let filename = "\(fileId)-\(file.name)"
            let data = file.data
            files[filename] = File(id: fileId, name: file.name, data: data)
        }

        super.init()
    }

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        let rootWrapper = FileWrapper(directoryWithFileWrappers: [:])
        guard let note = note,
              let doc = note.documentStruct
        else { return rootWrapper }

        let noteData = doc.data
        let noteWrapper = FileWrapper(regularFileWithContents: noteData)
        noteWrapper.preferredFilename = FileContentKey.note.rawValue

        rootWrapper.addFileWrapper(noteWrapper)
        rootWrapper.preferredFilename = note.title + ".beamNote"

        var files = [String: FileWrapper]()
        for (fileId, file) in self.files {
            let filename = "\(fileId)-\(file.name)"
            let fileWrapper = FileWrapper(regularFileWithContents: file.data)
            fileWrapper.preferredFilename = filename
            files[filename] = fileWrapper
        }

        if !files.isEmpty {
            let filesWrapper = FileWrapper(directoryWithFileWrappers: files)
            filesWrapper.preferredFilename = "media"
            rootWrapper.addFileWrapper(filesWrapper)
        }

        return rootWrapper
    }

    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        guard let noteWrapper = fileWrapper.fileWrappers?[FileContentKey.note.rawValue],
              let data = noteWrapper.regularFileContents
        else {
            throw Self.Error.incompleteNoteDocument
        }

        let decoder = BeamJSONDecoder()
        let note = try decoder.decode(BeamNote.self, from: data)

        let fileElements = note.allFileElements
        if !fileElements.isEmpty, let filesWrapper = fileWrapper.fileWrappers?[FileContentKey.media.rawValue],
           let fileWrappers = filesWrapper.fileWrappers {
            for fileWrapper in fileWrappers.values {
                guard let data = fileWrapper.regularFileContents else { continue }
                guard let filename = fileWrapper.filename else {
                    let id = BeamFileDBManager.uuidFor(data: data)
                    self.files[id.uuidString] = File(id: id, name: id.uuidString, data: data)
                    continue
                }
                let name = filename.count > 36 ? String(filename.prefix(filename.count - 36)) : filename
                let id = BeamFileDBManager.uuidFor(data: data)
                self.files[id.uuidString] = File(id: id, name: name, data: data)
            }
        }

        self.note = note
    }

    func importNote() throws {
        guard let note = note else { return }
        note.databaseId = DatabaseManager.defaultDatabase.id
        guard let docStruct = note.documentStruct else { return }

        // We use the same mecanism than when recieving notes from the sync, so that we can go thru a tested and well known code path:
        let documentManager = DocumentManager()
        try documentManager.receivedObjects([docStruct])

        let fileElements = note.allFileElements
        if !fileElements.isEmpty {
            for file in self.files.values {
                _ = try? BeamFileDBManager.shared.insert(name: file.name, data: file.data)
            }
        }
    }

    static let fileExtension = "beamNote"
    static let documentTypeName = "co.beamapp.note"

    enum Error: Swift.Error {
        case incompleteNoteDocument
    }

    private enum FileContentKey: String {
        case note = "Note"
        case media = "media"
    }

}
