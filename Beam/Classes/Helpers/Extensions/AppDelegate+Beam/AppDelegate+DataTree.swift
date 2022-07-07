import Foundation

extension AppDelegate {
    @IBAction func showDataTree(_ sender: Any) {
        if let dataTreeWindow = dataTreeWindow {
            dataTreeWindow.makeKeyAndOrderFront(window)
            return
        }
        dataTreeWindow = DataTreeWindow(contentRect: window?.frame ?? NSRect(origin: .zero, size: CGSize(width: 1300, height: 800)))
        dataTreeWindow?.center()
        dataTreeWindow?.makeKeyAndOrderFront(window)
    }
}
