//
//  BeamData.swift
//  Beam
//
//  Created by Sebastien Metrot on 31/10/2020.
//

import Foundation

class BeamData: ObservableObject {
    var _todaysNote: BeamNote?
    var todaysNote: BeamNote {
        if let note = _todaysNote, note.title == todaysName {
            return note
        }

        setupJournal()
        return _todaysNote!
    }
    @Published var journal: [BeamNote] = []

    var searchKit: SearchKit
    var scores = Scores()

    @Published var showTabStats = true

    var cookies: HTTPCookieStorage
    var documentManager: DocumentManager

    init() {
        documentManager = DocumentManager(coreDataManager: CoreDataManager.shared)

        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let directory = paths.first ?? "~/Application Data/BeamApp/"
        let indexPath = URL(fileURLWithPath: directory + "/index.sk")
        searchKit = SearchKit(indexPath)

        cookies = HTTPCookieStorage()
    }

    var todaysName: String {
        let fmt = DateFormatter()
        let today = Date()
        fmt.dateStyle = .long
        fmt.doesRelativeDateFormatting = false
        fmt.timeStyle = .none
        return fmt.string(from: today)
    }

    func setupJournal() {

        if let doc = documentManager.loadDocumentByTitle(title: todaysName) {
            #if DEBUG
            Logger.shared.logInfo("Today's note loaded:\n\(String(data: doc.data, encoding: .utf8)!)\n", category: .general)
            #endif
            let decoder = JSONDecoder()
            do {
                _todaysNote = try decoder.decode(BeamNote.self, from: doc.data)
            } catch {
                Logger.shared.logError("Unable to decode today's note", category: .general)
            }
        }

        if _todaysNote == nil {
            // Create the journal
            _todaysNote = BeamNote(title: todaysName)
            _todaysNote?.type = .journal
        }

        updateJournal()
    }

    func updateJournal() {
        var _journal = documentManager.loadDocumentsWithType(type: DocumentType.journal).compactMap { docStruct -> BeamNote? in
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(BeamNote.self, from: docStruct.data)
            } catch {
                Logger.shared.logError("Unable to decode note [[\(docStruct.title)]] (uid: \(docStruct.id)", category: .general)
            }
            return nil
        }

//        // purge journal from empty notes:
//        for note in _journal {
//            if note.title != todaysName, note.bullets?.count == 1, let bullet = note.bullets?.first, bullet.content.isEmpty {
//                note.delete()
//            } else {
//                newJournal.append(beamNoteFrom(note: note))
//            }
//        }

        _journal.insert(todaysNote, at: 0)
        journal = _journal
//        print("Journal updated:\n\(journal)\n")
    }
}
