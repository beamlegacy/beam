import Foundation

extension AppDelegate {
    @IBAction func showAllDocuments(_ sender: Any) {
        if let documentsWindow = documentsWindow {
            documentsWindow.makeKeyAndOrderFront(window)
            return
        }
        documentsWindow = DocumentsWindow(contentRect: window.frame)
        documentsWindow?.center()
        documentsWindow?.makeKeyAndOrderFront(window)
    }
}
