import Foundation
import BeamCore
import Combine
import AppKit

class LoggerCategoryTableViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    var categories: [String] = []
    var categoriesCount: [String: Int32] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        observeNotification()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        loadData()
        tableView.reloadData()

        let indexSet = IndexSet(integer: 0)
        tableView.selectRowIndexes(indexSet, byExtendingSelection: false)

        NotificationCenter.default.addObserver(self, selector: #selector(didSelectRow(_:)),
                                               name: NSTableView.selectionDidChangeNotification,
                                               object: tableView)
    }

    @objc
    func didSelectRow(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else {
            return
        }

        let selectedCategories = table.selectedRowIndexes.compactMap { categories[$0] }

        if let logController = parentSplit?.splitViewItems[1].viewController as? LoggerNSTableController {
            parentSplit?.progressIndicator?.startAnimation(nil)
            if table.selectedRowIndexes.contains(0) {
                logController.setCategories([])
            } else {
                logController.setCategories(selectedCategories)
            }
            parentSplit?.progressIndicator?.stopAnimation(nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var parentSplit: LoggerSplitViewController? {
       guard let splitVC = parent as? LoggerSplitViewController else { return nil }
       return splitVC
   }

    private func loadData() {
        parentSplit?.progressIndicator?.startAnimation(nil)

        categories = LogCategory.allCases.map { $0.rawValue }.sorted(by: { $0 < $1 })
        categories.insert("All Logs", at: 0)

        let keypathExp = NSExpression(forKeyPath: "category") // can be any column
        let expression = NSExpression(forFunction: "count:", arguments: [keypathExp])

        let countDesc = NSExpressionDescription()
        countDesc.expression = expression
        countDesc.name = "count"
        countDesc.expressionResultType = .integer64AttributeType

        let request: NSFetchRequest<NSFetchRequestResult> = LogEntry.fetchRequest()
        request.returnsObjectsAsFaults = false
        request.propertiesToGroupBy = ["category"]
        request.propertiesToFetch = ["category", countDesc]
        request.resultType = .dictionaryResultType

        if let results = try? CoreDataManager.shared.mainContext.fetch(request) {
            var all: Int32 = 0
            results.forEach {
                if let values = ($0 as? [String: Any]),
                   let category = values["category"] as? String,
                   let count = values["count"] as? Int32 {
                    all += count
                    categoriesCount[category] = count
                }
            }
            categoriesCount["All Logs"] = all
        }

        parentSplit?.progressIndicator?.stopAnimation(nil)
    }

    private var cancellables: [AnyCancellable] = []
    private func observeNotification() {
        NotificationCenter.default.publisher(for: .loggerInsert)
            .sink { notification in
                guard let logEntryId = (notification.object as? LogEntry)?.objectID,
                      let logEntry = CoreDataManager.shared.mainContext.object(with: logEntryId) as? LogEntry else {
                          return
                      }

                if let category = logEntry.category,
                   let categoryIndex = self.categories.firstIndex(of: category) {
                    self.categoriesCount[category] = (self.categoriesCount[category] ?? 0) + 1
                    self.categoriesCount["All Logs"] = (self.categoriesCount["All Logs"] ?? 0) + 1

                    self.tableView.reloadData(forRowIndexes: IndexSet(integer: categoryIndex),
                                              columnIndexes: IndexSet(integer: 1))

                    self.tableView.reloadData(forRowIndexes: IndexSet(integer: 0),
                                              columnIndexes: IndexSet(integer: 1))
                }
            }
            .store(in: &cancellables)
    }
}

extension LoggerCategoryTableViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return categories.count
    }
}

extension LoggerCategoryTableViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < categories.count else { return nil }

        let category = categories[row]
        switch tableColumn?.identifier {
        case NSUserInterfaceItemIdentifier(rawValue: "category"):
            let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "category")
            guard let cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView else { return nil }
            cellView.textField?.stringValue = category
            return cellView
        case NSUserInterfaceItemIdentifier(rawValue: "count"):
            let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "count")
            guard let cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView else { return nil }
            cellView.textField?.intValue = categoriesCount[category] ?? 0
            return cellView
        default: break
        }
        return nil
    }
}
