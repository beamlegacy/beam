//
//  ExportAllNoteSources.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 23/08/2021.
//

import Foundation
import BeamCore

fileprivate extension String {
    var quotedForCSV: String {
        "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

fileprivate extension Date {
    var toString: String {
        let dateFormater = DateFormatter()
        dateFormater.dateFormat = "y-MM-dd H:m:ss.SSS"
        return dateFormater.string(from: self)
    }
}
private func toCsv(columns: [String]) -> String {
    return columns.map { "\($0)".quotedForCSV }.joined(separator: ",") + "\n"
}

private func optionalToString<T>(_ elem: T?) -> String {
    guard let elem = elem else { return "<???>" }
    return "\(elem)"
}

private struct NoteAndSourcesRow {
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

    static let csvHeader: String = toCsv(columns: [
                                            "noteTitle",
                                            "noteCreatedAt",
                                            "noteId",
                                            "sourceUrl",
                                            "sourceAddedAt",
                                            "sourceSessionId",
                                            "sourceScore",
                                            "sourceType"])
    var csvRow: String {
        let columns: [String] = [
            noteTitle,
            noteCreatedAt.toString,
            noteId.uuidString,
            optionalToString(sourceUrl),
            sourceAddedAtString,
            sourceSessionIdString,
            optionalToString(sourceScore),
            optionalToString(sourceType)
        ]
        return toCsv(columns: columns)
    }
}

func export_all_note_sources() {
    let docManager = DocumentManager()
    let notesAndSources = docManager.allDocumentsTitles(includeDeletedNotes: true)
        .compactMap { title -> [NoteAndSourcesRow]? in
            guard let note = BeamNote.fetch(docManager, title: title, keepInMemory: false),
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

    let fileManager = FileManager.default
    guard let documentDirectory = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
        Logger.shared.logError("Unable to get document direction", category: .web)
        return
    }
    let noteSourcesFileURL = documentDirectory.appendingPathComponent("beam_all_note_sources \(BeamDate.now).csv")

    let noteSourcesCSV = NoteAndSourcesRow.csvHeader + notesAndSources.map {$0.csvRow} .joined()
    do {
        try noteSourcesCSV.write(to: noteSourcesFileURL, atomically: true, encoding: .utf8)
    } catch {
        Logger.shared.logError("Unable to save note sources to \(noteSourcesFileURL)", category: .web)
    }
    //swiftlint:disable:next print
    print("All note sources saved to file \(noteSourcesFileURL)")
}
