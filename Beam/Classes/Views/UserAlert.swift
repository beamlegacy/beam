import Foundation

class UserAlert {
    static func showMessage(message: String, informativeText: String? = nil, buttonTitle: String? = nil) {
        showAlert(message: message, informativeText: informativeText, buttonTitle: buttonTitle)
    }

    static func showError(message: String, informativeText: String? = nil, buttonTitle: String? = nil) {
        showAlert(message: message, informativeText: informativeText, buttonTitle: buttonTitle, style: .critical)
    }

    static func showError(message: String? = nil, error: Error) {
        showAlert(message: message ?? "Error", informativeText: error.localizedDescription, style: .critical)
    }

    static private func showAlert(message: String, informativeText: String? = nil, buttonTitle: String? = nil, style: NSAlert.Style = .informational) {
        let call = {
            let alert = NSAlert()
            alert.alertStyle = .critical

            alert.messageText = message

            if let informativeText = informativeText {
                alert.informativeText = informativeText
            }

            if let buttonTitle = buttonTitle {
                alert.addButton(withTitle: buttonTitle)
            }
            alert.runModal()
        }

        if Thread.isMainThread {
            call()
        } else {
            DispatchQueue.main.async { call() }
        }
    }
}
