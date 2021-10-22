import Foundation
import BeamCore
import Combine
import AppKit

class LoggerCategoryTableViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    var categories: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        observeNotification()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        loadData()
        tableView.reloadData()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

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
            if table.selectedRowIndexes.contains(0) {
                logController.setCategories([])
            } else {
                logController.setCategories(selectedCategories)
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var parentSplit: NSSplitViewController? {
       guard let splitVC = parent as? NSSplitViewController else { return nil }
       return splitVC
   }

    private func loadData() {
        categories = LogCategory.allCases.map { $0.rawValue }.sorted(by: { $0 < $1 })
        categories.insert("All Logs", at: 0)
    }

    private var cancellables: [AnyCancellable] = []
    private func observeNotification() {
        NotificationCenter.default.publisher(for: .loggerInsert)
            .sink { notification in
                guard let logEntryId = (notification.object as? LogEntry)?.objectID,
                      let logEntry = CoreDataManager.shared.mainContext.object(with: logEntryId) as? LogEntry else {
                          return
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
        default: break
        }
        return nil
    }
}
