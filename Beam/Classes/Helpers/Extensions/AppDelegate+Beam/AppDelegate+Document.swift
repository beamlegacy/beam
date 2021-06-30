import Foundation

extension AppDelegate {
    @IBAction func showAllDocuments(_ sender: Any) {
        if let documentsWindow = documentsWindow {
            documentsWindow.makeKeyAndOrderFront(window)
            return
        }
        documentsWindow = DocumentsWindow(contentRect: window?.frame ?? NSRect(origin: .zero, size: CGSize(width: 800, height: 600)))
        documentsWindow?.center()
        documentsWindow?.makeKeyAndOrderFront(window)
    }
}
