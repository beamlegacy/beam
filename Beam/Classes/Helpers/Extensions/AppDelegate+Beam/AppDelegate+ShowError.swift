import Foundation

extension AppDelegate {
    static func showError(_ error: Error) {
        UserAlert.showError(error: error)
    }

    static func showMessage(_ message: String) {
        DispatchQueue.main.async {
            UserAlert.showMessage(message: message)
        }
    }
}
