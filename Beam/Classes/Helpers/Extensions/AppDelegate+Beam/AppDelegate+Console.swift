import Foundation

extension AppDelegate {
    @IBAction func showConsole(_ sender: Any) {
        consoleWindow = consoleWindow ?? ConsoleWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600))
        consoleWindow?.center()
        consoleWindow?.makeKeyAndOrderFront(window)
    }
}
