import Foundation

extension AppDelegate {
    @IBAction func showAllFiles(_ sender: Any) {
        if let filesWindow = filesWindow {
            filesWindow.makeKeyAndOrderFront(window)
            return
        }
        guard let fileManager = data.currentAccount?.fileDBManager else { return }
        filesWindow = FilesWindow(contentRect: window?.frame ?? NSRect(origin: .zero, size: CGSize(width: 800, height: 600)), fileManager: fileManager)
        filesWindow?.center()
        filesWindow?.makeKeyAndOrderFront(window)
    }
}
