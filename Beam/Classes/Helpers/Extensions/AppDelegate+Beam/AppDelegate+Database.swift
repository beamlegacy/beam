import Foundation

extension AppDelegate {
    @IBAction func showAllDatabases(_ sender: Any) {
        databasesWindow = databasesWindow ?? DatabasesWindow(
            contentRect: window.frame)
        databasesWindow?.center()
        databasesWindow?.makeKeyAndOrderFront(window)
    }
}
