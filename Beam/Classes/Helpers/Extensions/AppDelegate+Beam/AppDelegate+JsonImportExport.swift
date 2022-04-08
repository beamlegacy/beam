import Foundation
import Cocoa
import BeamCore

extension AppDelegate {
    @IBAction func exportAllNotesToBeamNote(_ sender: Any) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true

        savePanel.title = loc("Choose the directory to export beamNote files")
        savePanel.begin { [weak savePanel] result in
            guard result == .OK, let selectedPath = savePanel?.url?.path
            else { savePanel?.close(); return }

            let baseURL = URL(fileURLWithPath: selectedPath)

            for id in self.documentManager.allDocumentsIds(includeDeletedNotes: false) {
                self.exportNoteToBeamNote(id: id, baseURL: baseURL)
            }
            savePanel?.close()
        }
    }

    func exportOneNoteToBeamNote(note: BeamNote) {
        let savePanel = NSSavePanel()
        // TODO: i18n
        savePanel.allowedFileTypes = ["beamNote"]
        savePanel.allowsOtherFileTypes = true
        savePanel.title = loc("Choose the file to export \(note.title)")
        savePanel.nameFieldStringValue = "\(note.type.journalDateString ?? note.title) \(note.id).beamNote"
        savePanel.begin { [weak savePanel] result in
            guard result == .OK, let selectedPath = savePanel?.url?.path
            else { savePanel?.close(); return }

            let url = URL(fileURLWithPath: selectedPath)
            self.exportNoteToBeamNote(id: note.id, baseURL: url.deletingLastPathComponent(), toFile: url)

            savePanel?.close()
        }
    }

    func exportNotesToBeamNote(_ notes: [BeamNote]) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        // TODO: i18n
        savePanel.title = loc("Choose the directory to export json files to")
        savePanel.begin { [weak savePanel] result in
            guard result == .OK, let selectedPath = savePanel?.url?.path
            else { savePanel?.close(); return }

            let baseURL = URL(fileURLWithPath: selectedPath)

            for note in notes {
                self.exportNoteToBeamNote(id: note.id, baseURL: baseURL)
            }
            savePanel?.close()
        }
    }

    func exportNoteToBeamNote(id: UUID, baseURL: URL, toFile fileUrl: URL? = nil) {
        if let note = BeamNote.fetch(id: id, includeDeleted: false, keepInMemory: false, decodeChildren: true) {
            let url = fileUrl ?? URL(fileURLWithPath: "\(note.type.journalDateString ?? note.title) \(id).beamNote", relativeTo: baseURL)
            do {
                let document = BeamNoteDocumentWrapper(note: note)
                try document.write(to: url, ofType: "beamNote")
            } catch {
                UserAlert.showError(message: error.localizedDescription)

                return
            }
        }
    }

    fileprivate func importFile(_ url: URL) {
        if url.hasDirectoryPath {
            // looks for all files and try to decode / add them
            let fm = FileManager()
            do {
                for child in try fm.contentsOfDirectory(atPath: url.path) {
                    importFile(URL(fileURLWithPath: child, relativeTo: url))
                }
            } catch {
                Logger.shared.logError("Unable to list files in \(url)", category: .general)
            }
        } else {
            // try to decode and import this file
            guard let data = try? Data(contentsOf: url) else {
                Logger.shared.logError("Unable to import data from \(url)", category: .general)
                return
            }

            do {
                let noteDocument = try BeamNoteDocumentWrapper(fileWrapper: FileWrapper(url: url, options: .immediate))
                try noteDocument.importNote()
            } catch {
                UserAlert.showError(message: "Unable to import \(url)", error: error)
            }
        }
    }

    @IBAction func importJSONFiles(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        // TODO: i18n
        openPanel.title = loc("Choose the files import")
        openPanel.begin { [weak openPanel] result in
            guard result == .OK
            else { openPanel?.close(); return }

            for url in openPanel?.urls ?? [] {
                self.importFile(url)
            }
            openPanel?.close()
        }
    }
}
