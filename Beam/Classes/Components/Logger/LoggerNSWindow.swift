import Foundation

class LoggerNSWindow: NSWindow {
    @IBAction func deleteAll(_ sender: Any) {
        guard let delegate = self.delegate as? LoggerSplitViewController else { return }

        delegate.logsController?.deleteAll()
    }

    @IBAction func addMarker(_ sender: Any) {
        guard let delegate = self.delegate as? LoggerSplitViewController else { return }

        delegate.logsController?.addMarker()
    }

    @IBAction func hideSideBar(_ sender: Any) {
        guard let delegate = self.delegate as? LoggerSplitViewController else { return }

        delegate.toggleCategoryPanel()
    }

    @IBAction func download(_ sender: Any) {
        guard let delegate = self.delegate as? LoggerSplitViewController else { return }

        delegate.logsController?.download()
    }
}
