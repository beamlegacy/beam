import Foundation

extension AppDelegate {
    @IBAction func showAllDocuments(_ sender: Any) {
        documentsWindow = documentsWindow ?? DocumentsWindow(
            contentRect: window.frame)
        documentsWindow?.center()
        documentsWindow?.makeKeyAndOrderFront(window)
    }
}
