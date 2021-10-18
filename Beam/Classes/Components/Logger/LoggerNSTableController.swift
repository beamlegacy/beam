import Foundation
import AppKit
import SwiftUI
import Combine
import BeamCore

class LoggerNSTableController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    var logEntries: [LogEntry] = []
    private var textField: NSTextField = NSTextField()
    private var selectedCategory: String?
    private var searchText: String?

    public func deleteAll() {
        LoggerRecorder.shared.deleteAll(selectedCategory)
        logEntries = []
        tableView.reloadData()
    }

    public func addMarker() {
        Logger.shared.logDebug("--------------------------------------------------------------------------",
                               category: .marker)
    }

    public func download() {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = "BeamLogs.csv"
        savePanel.begin { result in
            guard result == .OK, let url = savePanel.url else {
                savePanel.close()
                return
            }

            if let fileHandle = try? FileHandle(forWritingTo: url) {
                self.logEntries.forEach { logEntry in
                    let csvLine = [logEntry.created_at?.iso8601withFractionalSeconds ?? "",
                                    logEntry.level ?? "",
                                    logEntry.category ?? "",
                                    logEntry.log?.quotedForCSV ?? ""].joined(separator: ",")

                    fileHandle.write(csvLine.asData)
                    fileHandle.write("\n".asData)
                }
                fileHandle.closeFile()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        observeNotification()
        tableView.doubleAction = #selector(didDoubleSelectRow)
    }

    override func viewWillAppear() {
        super.viewWillAppear()

    }

    override func viewDidAppear() {
        super.viewDidAppear()
        loadData()
        tableView.reloadData()
        tableView.scrollRowToVisible(self.logEntries.count - 1)
    }

    public func setCategory(_ category: String?) {
        selectedCategory = category
        loadData()
        tableView.reloadData()
        tableView.scrollRowToVisible(self.logEntries.count - 1)
    }

    public func setSearchText(_ text: String?) {
        searchText = text
        loadData()
        tableView.reloadData()
        tableView.scrollRowToVisible(self.logEntries.count - 1)
    }

    private func loadData() {
        let request: NSFetchRequest<LogEntry> = LogEntry.fetchRequest()

        request.fetchLimit = 500

        var predicates: [NSPredicate] = []
        if let selectedCategory = selectedCategory {
            predicates.append(NSPredicate(format: "category IN %@", [selectedCategory, "marker"]))
        }

        if let searchText = searchText, !searchText.isEmpty {
            predicates.append(NSPredicate(format: "log CONTAINS[cd] %@", searchText))
            request.fetchLimit = 0
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        request.sortDescriptors = [NSSortDescriptor(keyPath: \LogEntry.created_at,
                                                    ascending: false)]

        do {
            logEntries = try CoreDataManager.shared.mainContext.fetch(request).reversed()
        } catch {
            //swiftlint:disable:next print
            print(error.localizedDescription)
        }
    }
    private var cancellables: [AnyCancellable] = []
    private func observeNotification() {
        NotificationCenter.default.publisher(for: .loggerInsert)
            .sink { notification in
                guard let logEntryId = (notification.object as? LogEntry)?.objectID,
                      let logEntry = CoreDataManager.shared.mainContext.object(with: logEntryId) as? LogEntry else {
                          return
                      }

                if let searchText = self.searchText,
                   !searchText.isEmpty,
                   logEntry.log?.range(of: searchText, options: .caseInsensitive) == nil,
                   logEntry.category != "marker" {
                    return
                }

                if let selectedCategory = self.selectedCategory,
                   ![selectedCategory, "marker"].contains(logEntry.category) {
                    return
                }

                self.logEntries.append(logEntry)

                self.tableView.insertRows(at: IndexSet(integer: self.logEntries.count - 1),
                                          withAnimation: [])

                self.tableView.scrollRowToVisible(self.logEntries.count - 1, animated: true)
            }
            .store(in: &cancellables)
    }

    @objc
    func didDoubleSelectRow() {
        let row = tableView.selectedRow

        let logEntry = logEntries[row]

        guard let log = logEntry.log else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(log, forType: .string)
    }
}

extension LoggerNSTableController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return logEntries.count
    }
}

extension LoggerNSTableController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < logEntries.count else { return tableView.rowHeight }
        let logEntry = logEntries[row]
        guard let log = logEntry.log else { return tableView.rowHeight }

        textField.stringValue = log

        guard let tableColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "log")),
              let dataCell = tableColumn.dataCell as? NSCell else {
            return tableView.rowHeight
        }

        dataCell.stringValue = log
        dataCell.wraps = true
        let rect = CGRect(x: 0, y: 0, width: tableColumn.width, height: CGFloat.greatestFiniteMagnitude)
        return max(dataCell.cellSize(forBounds: rect).height + 10.0, tableView.rowHeight)
    }

    // swiftlint:disable:next cyclomatic_complexity
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < logEntries.count else { return nil }

        let logEntry = logEntries[row]
        switch tableColumn?.identifier {
        case NSUserInterfaceItemIdentifier(rawValue: "createdAt"):
            let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "createdAt")
            guard let cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView else { return nil }
            cellView.textField?.stringValue = Self.dateFormat.string(from: logEntry.created_at!)
            return cellView
        case NSUserInterfaceItemIdentifier(rawValue: "level"):
            let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "level")
            guard let cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView else { return nil }
            cellView.textField?.stringValue = logEntry.level ?? "-"
            return cellView
        case NSUserInterfaceItemIdentifier(rawValue: "category"):
            let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "category")
            guard let cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView else { return nil }
            cellView.textField?.stringValue = logEntry.category ?? "-"
            return cellView
        case NSUserInterfaceItemIdentifier(rawValue: "log"):
            let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "log")
            guard let cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView else { return nil }

            if let duration = logEntry.duration {
                cellView.textField?.stringValue = String(format: "%@ in %.4fsec", logEntry.log ?? "", duration.doubleValue)
            } else {
                cellView.textField?.stringValue = logEntry.log ?? "-"
            }

            return cellView
        default: break
        }
        return nil
    }

    static private let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}

fileprivate extension String {
    var quotedForCSV: String {
        "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
