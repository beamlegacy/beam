import Foundation
import Cocoa
import BeamCore

extension AppDelegate {
    // MARK: - JSON Export / Import
    @IBAction func exportAllNotesToJSON(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        // TODO: i18n
        openPanel.title = "Choose the directory to export json files"
        openPanel.begin { [weak openPanel] result in
            guard result == .OK, let selectedPath = openPanel?.url?.path
            else { openPanel?.close(); return }

            let baseURL = URL(fileURLWithPath: selectedPath)

            for id in self.documentManager.allDocumentsIds(includeDeletedNotes: false) {
                self.exportNote(id: id, baseURL: baseURL)
            }
            openPanel?.close()
        }
    }

    func exportNotesToJSON(_ notes: [BeamNote]) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        // TODO: i18n
        openPanel.title = "Choose the directory to export json files to"
        openPanel.begin { [weak openPanel] result in
            guard result == .OK, let selectedPath = openPanel?.url?.path
            else { openPanel?.close(); return }

            let baseURL = URL(fileURLWithPath: selectedPath)

            for note in notes {
                self.exportNote(id: note.id, baseURL: baseURL)
            }
            openPanel?.close()
        }
    }

    func exportOneNoteToJSON(note: BeamNote) {
        let savePanel = NSSavePanel()
        // TODO: i18n
        savePanel.allowedFileTypes = ["json"]
        savePanel.allowsOtherFileTypes = true
        savePanel.title = "Choose the file to export \(note.title)"
        savePanel.nameFieldStringValue = "\(note.type.journalDateString ?? note.title) \(note.id).json"
        savePanel.begin { [weak savePanel] result in
            guard result == .OK, let selectedPath = savePanel?.url?.path
            else { savePanel?.close(); return }

            self.exportNote(id: note.id, toFile: URL(fileURLWithPath: selectedPath))

            savePanel?.close()
        }
    }

    func exportNote(id: UUID, baseURL: URL? = nil, toFile fileUrl: URL? = nil) {
        assert((baseURL == nil) != (fileUrl == nil))
        if let note = BeamNote.fetch(id: id, includeDeleted: false, keepInMemory: false, decodeChildren: true) {
            guard let doc = note.documentStruct else {
                return
            }
            let url = fileUrl ?? URL(fileURLWithPath: "\(note.type.journalDateString ?? note.title) \(id).json", relativeTo: baseURL)
            do {
                try doc.data.write(to: url)
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
            let decoder = JSONDecoder()
            guard let note = try? decoder.decode(BeamNote.self, from: data) else {
                Logger.shared.logError("Unable to decode beam note from \(url)", category: .general)
                return
            }
            note.save()
        }
    }

    @IBAction func importJSONFiles(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        // TODO: i18n
        openPanel.title = "Choose the json files or directories to import"
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
