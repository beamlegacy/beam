import Foundation
import Cocoa
import BeamCore

extension AppDelegate {
    @IBAction func exportAllNotesToBeamNote(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.title = loc("Choose the directory to export beamNote files")
        openPanel.begin { [weak openPanel] result in
            defer { openPanel?.close() }

            guard result == .OK, let selectedPath = openPanel?.url?.path,
                  let ids = try? self.data.currentDocumentCollection?.fetchIds(filters: [])
            else { return }

            let baseURL = URL(fileURLWithPath: selectedPath)

            for id in ids {
                self.exportNoteToBeamNote(id: id, baseURL: baseURL)
            }
        }
    }

    func exportOneNoteToBeamNote(note: BeamNote) {
        let savePanel = NSSavePanel()
        // TODO: i18n
        savePanel.allowedFileTypes = [BeamNoteDocumentWrapper.fileExtension]
        savePanel.allowsOtherFileTypes = true
        savePanel.title = loc("Choose the file to export \(note.title)")
        savePanel.nameFieldStringValue = BeamNoteDocumentWrapper.preferredFilename(for: note, withExtension: true)
        savePanel.begin { [weak savePanel] result in
            defer { savePanel?.close() }

            guard result == .OK, let selectedPath = savePanel?.url?.path else { return }

            let url = URL(fileURLWithPath: selectedPath)
            self.exportNoteToBeamNote(id: note.id, baseURL: url.deletingLastPathComponent(), toFile: url)
        }
    }

    func exportNotesToBeamNote(_ notes: [BeamNote]) {
        let openPanel = NSOpenPanel()

        openPanel.canCreateDirectories = true
        openPanel.canChooseDirectories = true
        // TODO: i18n
        openPanel.title = loc("Choose the directory to export json files to")
        openPanel.begin { [weak openPanel] result in
            defer { openPanel?.close() }
            guard result == .OK, let selectedPath = openPanel?.url?.path else { return }

            let baseURL = URL(fileURLWithPath: selectedPath)

            for note in notes {
                self.exportNoteToBeamNote(id: note.id, baseURL: baseURL)
            }
        }
    }

    func exportNoteToBeamNote(id: UUID, baseURL: URL, toFile fileUrl: URL? = nil) {
        guard let note = BeamNote.fetch(id: id, keepInMemory: false, decodeChildren: true) else {
            UserAlert.showError(message: "Unable to retrieve note with id: \(id)"); return
        }
        do {
            let filename = BeamNoteDocumentWrapper.preferredFilename(for: note, withExtension: true)
            let url = fileUrl ?? URL(fileURLWithPath: filename, relativeTo: baseURL)
            let document = BeamNoteDocumentWrapper(note: note)
            try document.write(to: url, ofType: BeamNoteDocumentWrapper.fileExtension)
        } catch {
            UserAlert.showError(message: error.localizedDescription)
        }
    }

    fileprivate func importFile(_ url: URL, fm: FileManager = .default) {
        if url.hasDirectoryPath, url.pathExtension != BeamNoteDocumentWrapper.fileExtension {
            // looks for all files and try to decode / add them
            do {
                for child in try fm.contentsOfDirectory(atPath: url.path) {
                    importFile(URL(fileURLWithPath: child, relativeTo: url), fm: fm)
                }
            } catch {
                Logger.shared.logError("Unable to list files in \(url)", category: .general)
            }
        } else {
            // try to decode and import this file
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

    // MARK: Markdown export

    func exportNotesToMarkdown(_ notes: [BeamNote]) {
        guard !notes.isEmpty else { return }

        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.title = loc("Choose the directory to export to Markdown")
        openPanel.begin { [weak openPanel] result in
            guard result == .OK, let selectedURL = openPanel?.url else { return }

            var failedCount: UInt = .zero

            for note in notes {
                do {
                    let export = try MarkdownExporter.export(of: note)
                    try export.write(to: selectedURL)
                } catch {
                    Logger.shared.logError("Error exporting \(note) to Markdown: \(error)", category: .general)
                    failedCount += 1
                }
            }

            if failedCount != .zero {
                UserAlert.showError(message: "Failed to export \(failedCount) \(failedCount > 1 ? "notes" : "note") to Markdown.")
            }
        }
    }
}
