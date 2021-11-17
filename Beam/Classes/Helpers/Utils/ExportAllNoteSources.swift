//
//  ExportAllNoteSources.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 23/08/2021.
//

import Foundation
import BeamCore

fileprivate extension Date {
    var toString: String {
        let dateFormater = DateFormatter()
        dateFormater.dateFormat = "y-MM-dd H:m:ss.SSS"
        return dateFormater.string(from: self)
    }
}

private struct NoteAndSourcesRow: CsvRow {
    let noteTitle: String
    let noteCreatedAt: Date
    let noteId: UUID
    var sourceUrl: String?
    var sourceAddedAt: Date?
    var sourceScore: Float?
    var sourceType: Int?
    var sourceSessionId: UUID?

    private var sourceAddedAtString: String {
        guard let sourceAddedAt = sourceAddedAt else { return "<???>" }
        return sourceAddedAt.toString
    }
    private var sourceSessionIdString: String {
        guard let sourceSessionId = sourceSessionId else { return "<???>" }
        return sourceSessionId.uuidString
    }

    static var columnNames: [String] { [
        "noteTitle",
        "noteCreatedAt",
        "noteId",
        "sourceUrl",
        "sourceAddedAt",
        "sourceSessionId",
        "sourceScore",
        "sourceType"
        ]
    }

    var columns: [String] { [
            noteTitle,
            noteCreatedAt.toString,
            noteId.uuidString,
            optionalToString(sourceUrl),
            sourceAddedAtString,
            sourceSessionIdString,
            optionalToString(sourceScore),
            optionalToString(sourceType)
        ]
    }
}

func export_all_note_sources(to url: URL?) {
    guard let url = url else { return }

    let documentManager = DocumentManager()
    let notesAndSources = documentManager.allDocumentsTitles(includeDeletedNotes: true)
        .compactMap { title -> [NoteAndSourcesRow]? in
            guard let note = BeamNote.fetch(title: title, keepInMemory: false),
                  !note.type.isJournal else { return nil }
            let sem = DispatchSemaphore(value: 0)
            note.sources.refreshScores { sem.signal() }
            sem.wait()
            if note.sources.count > 0 {
                return note.sources.getAll().map { s in
                    return NoteAndSourcesRow(
                        noteTitle: note.title,
                        noteCreatedAt: note.creationDate,
                        noteId: note.id,
                        sourceUrl: (LinkStore.shared.linkFor(id: s.urlId)?.url) ?? "<???>",
                        sourceAddedAt: s.addedAt,
                        sourceScore: s.score,
                        sourceType: s.type.rawValue,
                        sourceSessionId: s.sessionId
                    )
            }
            } else {
                return [NoteAndSourcesRow(noteTitle: note.title, noteCreatedAt: note.creationDate, noteId: note.id)]
            }
    }.joined()

    let writer = CsvRowsWriter(header: NoteAndSourcesRow.header, rows: Array(notesAndSources))
    let destination = url.appendingPathComponent("beam_all_note_sources-\(BeamDate.now).csv")
    do {
        try writer.overWrite(to: destination)
    } catch {
        Logger.shared.logError("Unable to save note sources to \(destination)", category: .web)
    }
    //swiftlint:disable:next print
    print("All note sources saved to file \(destination)")
}
