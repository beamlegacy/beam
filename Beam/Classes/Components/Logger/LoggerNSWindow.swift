import Foundation

class LoggerNSWindow: NSWindow {
    static private var _instances = 0
    static private var instancesSema = DispatchSemaphore(value: 1)

    static var instances: Int {
        get {
            instancesSema.wait()
            defer { instancesSema.signal() }

            return _instances
        }

        set {
            instancesSema.wait()
            defer { instancesSema.signal() }

            _instances = newValue
        }
    }

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

    @IBAction func exportLogs(_ sender: Any) {
        guard let delegate = self.delegate as? LoggerSplitViewController else { return }

        delegate.logsController?.exportLogs()
    }

    @IBAction func importLogs(_ sender: Any) {
        guard let delegate = self.delegate as? LoggerSplitViewController else { return }

        delegate.logsController?.importLogs()
    }

    @IBAction func live(_ sender: Any) {
        guard let button = sender as? NSButton,
              let delegate = self.delegate as? LoggerSplitViewController,
              let logsController = delegate.logsController else { return }

        if logsController.automaticScroll {
            button.image = NSImage(systemSymbolName: "livephoto.slash", accessibilityDescription: nil)
            logsController.automaticScroll = false
        } else {
            button.image = NSImage(systemSymbolName: "livephoto", accessibilityDescription: nil)
            logsController.automaticScroll = true
        }
    }
}
