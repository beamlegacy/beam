import Foundation

extension AppDelegate {
    @IBAction func showLogs(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil) // type storyboard name instead of Main
        guard let windowController = storyboard.instantiateController(withIdentifier: "LoggerWindowController") as? LoggerWindowController else {
            return
        }

        windowController.window?.center()
        windowController.window?.titleVisibility = .hidden
        windowController.window?.makeKeyAndOrderFront(window)
    }
}
