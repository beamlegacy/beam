import Foundation

extension AppDelegate {
    @IBAction func showAllDatabases(_ sender: Any) {
        if let databasesWindow = databasesWindow {
            databasesWindow.makeKeyAndOrderFront(window)
            return
        }
        databasesWindow = DatabasesWindow(contentRect: window?.frame ?? NSRect(origin: .zero, size: CGSize(width: 800, height: 600)))
        databasesWindow?.center()
        databasesWindow?.makeKeyAndOrderFront(window)
    }
}
