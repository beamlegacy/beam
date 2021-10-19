import Foundation

extension AppDelegate {
    @IBAction func showAllFiles(_ sender: Any) {
        if let filesWindow = filesWindow {
            filesWindow.makeKeyAndOrderFront(window)
            return
        }
        filesWindow = FilesWindow(contentRect: window?.frame ?? NSRect(origin: .zero, size: CGSize(width: 800, height: 600)))
        filesWindow?.center()
        filesWindow?.makeKeyAndOrderFront(window)
    }
}
