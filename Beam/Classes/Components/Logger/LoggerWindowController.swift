import Foundation

// This will be instantly deallocated and replaced by LoggerSplitViewController
class LoggerWindowController: NSWindowController {
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var searchField: NSSearchField!
    override func windowDidLoad() {
        super.windowDidLoad()

        if let delegate = contentViewController as? LoggerSplitViewController {
            window?.delegate = delegate
            searchField.delegate = delegate
            delegate.progressIndicator = progressIndicator
        }
    }
}
