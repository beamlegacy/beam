import Foundation

extension AppDelegate {
    @IBAction func showAllDatabases(_ sender: Any) {
        if let databasesWindow = databasesWindow {
            databasesWindow.makeKeyAndOrderFront(window)
            return
        }
        databasesWindow = DatabasesWindow(contentRect: window.frame)
        databasesWindow?.center()
        databasesWindow?.makeKeyAndOrderFront(window)
    }
}
