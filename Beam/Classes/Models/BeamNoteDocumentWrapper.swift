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
    var data: BeamData?
    private(set) var note: BeamNote?

    private struct File {
        var id: UUID
        var name: String
        var data: Data
    }

    private var files = [String: File]()

    init(fileWrapper: FileWrapper, data: BeamData?) throws {
        self.data = data
        super.init()
        try read(from: fileWrapper, ofType: Self.documentTypeName)
    }

    init(note: BeamNote, data: BeamData?) {
        self.note = note
        self.data = data
        for (fileId, _) in note.allFileElements {
            guard let file = try? data?.fileDBManager?.fetch(uid: fileId) else { continue }
            let data = file.data
            files[fileId.uuidString] = File(id: fileId, name: file.name, data: data)
        }

        super.init()
    }

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        let rootWrapper = FileWrapper(directoryWithFileWrappers: [:])
        guard let note = note,
              let doc = note.document
        else { return rootWrapper }

        let noteData = doc.data
        let noteWrapper = FileWrapper(regularFileWithContents: noteData)
        noteWrapper.preferredFilename = FileContentKey.note.rawValue

        rootWrapper.addFileWrapper(noteWrapper)
        rootWrapper.preferredFilename = Self.preferredFilename(for: note, withExtension: true)

        var files = [String: FileWrapper]()
        for (fileId, file) in self.files {
            let filename = "\(fileId)-\(file.name.prefix(Self.maxLength))"
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
        guard let note = note,
              let database = BeamData.shared.currentDatabase else { return }
        note.owner = database
        guard let doc = note.document else { return }

        // We use the same mecanism than when recieving notes from the sync, so that we can go thru a tested and well known code path:
        try AppData.shared.currentAccount?.documentSynchroniser?.receivedObjects([doc])

        let fileElements = note.allFileElements
        if !fileElements.isEmpty {
            for file in self.files.values {
                _ = try? data?.fileDBManager?.insert(name: file.name, data: file.data)
            }
        }
    }

    static let fileExtension = "beamNote"
    static let documentTypeName = "co.beamapp.note"

    static func preferredFilename(for note: BeamNote, withExtension: Bool = false) -> String {
        let fileName = "\(note.title.prefix(maxLength))-\(note.id.uuidString)"
        if withExtension {
            return "\(fileName).\(fileExtension)"
        }
        return fileName
    }

    /// max length for title in notes filename sand file name for medias.
    private static let maxLength: Int = 50

    enum Error: Swift.Error {
        case incompleteNoteDocument
    }

    private enum FileContentKey: String {
        case note = "Note"
        case media = "media"
    }

}
