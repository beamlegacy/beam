import Foundation

class LoggerSplitViewController: NSSplitViewController {
    private var searchTask: DispatchWorkItem?
    var categoryController: LoggerCategoryTableViewController? {
        splitViewItems.first?.viewController as? LoggerCategoryTableViewController
    }
    var logsController: LoggerNSTableController? {
        splitViewItems[1].viewController as? LoggerNSTableController
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        if let leftVC = splitViewItems.first?.viewController {
            leftVC.view.widthAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true
        }
    }

    public func toggleCategoryPanel() {
        splitViewItems[0].animator().isCollapsed = !splitViewItems[0].isCollapsed
    }
}

extension LoggerSplitViewController: NSWindowDelegate {

}

extension LoggerSplitViewController: NSTextFieldDelegate, NSSearchFieldDelegate {
    func searchFieldDidEndSearching(_ searchField: NSSearchField) {
    }

    func searchFieldDidStartSearching(_ searchField: NSSearchField) {
    }

    func controlTextDidChange(_ obj: Notification) {
        searchTask?.cancel()

        let task = DispatchWorkItem { [weak self] in
            self?.logsController?.setSearchText((obj.object as? NSSearchField)?.stringValue)
        }
        self.searchTask = task

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: task)
    }
}
