import Foundation
import AppKit
import SwiftUI
import Combine
import BeamCore

class LoggerNSTableController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    var logEntries: [LogEntry] = []
    private var textField: NSTextField = NSTextField()
    private var selectedCategories: [String] = []

    private var searchText: String?

    var automaticScroll = true

    public func deleteAll() {
        if selectedCategories.isEmpty {
            LoggerRecorder.shared.deleteAll()
        } else {
            selectedCategories.forEach {
                LoggerRecorder.shared.deleteAll($0)
            }
        }
        logEntries = []
        tableView.reloadData()
    }

    public func addMarker() {
        Logger.shared.logDebug("--------------------------------------------------------------------------",
                               category: .marker)
    }

    public func exportLogs() {
        AppDelegate.main.export(logEntries: logEntries)
    }

    public func importLogs() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.title = "Select logs to import"
        openPanel.begin { [weak openPanel] result in
            guard result == .OK, let selectedPath = openPanel?.url?.path else { openPanel?.close(); return }

            guard let data = NSData(contentsOfFile: selectedPath) as Data?, let dataString = data.asString else { return }

            let seq = CSVUnescapingSequence(input: dataString)
            let parser = CSVParser(input: seq)

            var index = 0
            for line in parser {
                let newLogEntry = LogEntry(context: CoreDataManager.shared.mainContext)
                newLogEntry.level = line[1]
                newLogEntry.category = line[2]
                newLogEntry.log = line[3]
                newLogEntry.created_at = line[0].iso8601withFractionalSeconds
                index += 1
            }

            try? CoreDataManager.shared.mainContext.save()

            self.loadData()
            self.tableView.reloadData()
            self.tableView.scrollRowToVisible(self.logEntries.count - 1)

            openPanel?.close()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        observeNotification()
        tableView.doubleAction = #selector(didDoubleSelectRow)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        loadData()
        tableView.reloadData()
        tableView.scrollRowToVisible(self.logEntries.count - 1)
    }

    public func setCategories(_ categories: [String]) {
        selectedCategories = categories
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

        var predicates: [NSPredicate] = []
        if !selectedCategories.isEmpty {
            selectedCategories.append("marker")
            predicates.append(NSPredicate(format: "category IN %@", selectedCategories))
        }

        if let searchText = searchText, !searchText.isEmpty {
            var searchPredicate = NSPredicate(format: "log CONTAINS[cd] %@", searchText)
            let levelPredicate = NSPredicate(format: "level CONTAINS[cd] %@", searchText)

            if selectedCategories.isEmpty {
                let categoryPredicate = NSPredicate(format: "category CONTAINS[cd] %@", searchText)
                let markerPredicate = NSPredicate(format: "category IN %@", ["marker"])
                searchPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [searchPredicate,
                                                                                     categoryPredicate,
                                                                                     levelPredicate,
                                                                                     markerPredicate])
                predicates.append(searchPredicate)
            } else {
                predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [searchPredicate,
                                                                                     levelPredicate]))
            }
        }
        logEntries = LoggerRecorder.shared.getEntries(with: NSCompoundPredicate(andPredicateWithSubpredicates: predicates),
                                                      and: [NSSortDescriptor(keyPath: \LogEntry.created_at, ascending: false)]) ?? []
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
                   logEntry.category?.range(of: searchText, options: .caseInsensitive) == nil,
                   logEntry.category != "marker" {
                    return
                }

                if !self.selectedCategories.isEmpty,
                   let category = logEntry.category,
                   !self.selectedCategories.contains(category) {
                    return
                }

                if self.automaticScroll {
                    if self.logEntries.count > 500 {
                        self.logEntries.removeFirst()
                        self.tableView.removeRows(at: IndexSet(integer: 0),
                                                  withAnimation: [])
                    }

                    self.logEntries.append(logEntry)
                    self.tableView.insertRows(at: IndexSet(integer: self.logEntries.count - 1),
                                              withAnimation: [])

                    self.tableView.scrollRowToVisible(self.logEntries.count - 1, animated: true)
                } else {
                    self.logEntries.append(logEntry)
                    self.tableView.insertRows(at: IndexSet(integer: self.logEntries.count - 1),
                                              withAnimation: [])
                }
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

        // Some logs are way too big, and calculating their height is too slow
        guard log.count <= 10240 else { return tableView.rowHeight * 20 }

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
        formatter.dateFormat = "y-MM-dd H:mm:ss.SSS"
        return formatter
    }()
}

fileprivate extension String {
    var quotedForCSV: String {
        "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
