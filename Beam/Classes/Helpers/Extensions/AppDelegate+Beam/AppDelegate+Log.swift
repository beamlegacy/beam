import Foundation
import BeamCore

extension AppDelegate {
    @IBAction func obtainLogs(_ sender: Any) {
        let logEntries: [LogEntry] = LoggerRecorder.shared.getEntries(with: NSCompoundPredicate(andPredicateWithSubpredicates: []),
                                                                      and: [NSSortDescriptor(keyPath: \LogEntry.created_at, ascending: false)],
                                                                      for: 1000) ?? []
        export(logEntries: logEntries)
    }

    @IBAction func showLogs(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil) // type storyboard name instead of Main
        guard let windowController = storyboard.instantiateController(withIdentifier: "LoggerWindowController") as? LoggerWindowController else {
            return
        }

        windowController.window?.center()
        windowController.window?.titleVisibility = .hidden
        windowController.window?.makeKeyAndOrderFront(window)
    }

    public func export(logEntries: [LogEntry]) {
        guard !logEntries.isEmpty else { return }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = "BeamLogs-\(BeamDate.now.iso8601withFractionalSeconds).csv"
        savePanel.begin { result in
            guard result == .OK, let url = savePanel.url else {
                savePanel.close()
                return
            }

            Logger.shared.logDebug("Writing logs at \(url)", category: .general)
            do {
                FileManager.default.createFile(atPath: url.path,
                                               contents: nil,
                                               attributes: nil)
                let fileHandle = try FileHandle(forWritingTo: url)

                logEntries.forEach { logEntry in
                    let csvLine = [logEntry.created_at?.iso8601withFractionalSeconds ?? "",
                                   logEntry.level ?? "",
                                   logEntry.category ?? "",
                                   logEntry.log?.quotedForCSV ?? ""].joined(separator: ",")

                    fileHandle.write(csvLine.asData)
                    fileHandle.write("\n".asData)
                }
                Logger.shared.logDebug("Wrote \(logEntries.count) log entries", category: .general)
                fileHandle.closeFile()
            } catch {
                Logger.shared.logError("Error opening \(url): \(error.localizedDescription)", category: .general)
            }
        }
    }
}

fileprivate extension String {
    var quotedForCSV: String {
        "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
