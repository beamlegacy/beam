import Foundation

extension AppDelegate {
    static func showError(_ error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.alertStyle = .critical
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    static func showMessage(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.alertStyle = .informational
            alert.runModal()
        }
    }
}
