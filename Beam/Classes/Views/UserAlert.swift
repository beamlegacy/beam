import Foundation

class UserAlert {
    static func showMessage(message: String, informativeText: String? = nil, buttonTitle: String? = nil, secondaryButtonTitle: String? = nil, buttonAction: (() -> Void)? = nil) {
        showAlert(message: message, informativeText: informativeText, buttonTitle: buttonTitle, secondaryButtonTitle: secondaryButtonTitle, buttonAction: buttonAction)
    }

    static func showMessage(message: String, informativeText: String? = nil, buttonTitle: String? = nil) {
        showAlert(message: message, informativeText: informativeText, buttonTitle: buttonTitle)
    }

    static func showMessage(message: String, informativeText: String? = nil, buttonTitle: String? = nil, buttonAction: (() -> Void)? = nil) {
        showAlert(message: message, informativeText: informativeText, buttonTitle: buttonTitle, buttonAction: buttonAction)
    }

    static func showError(message: String, informativeText: String? = nil, buttonTitle: String? = nil) {
        showAlert(message: message, informativeText: informativeText, buttonTitle: buttonTitle, style: .critical)
    }

    static func showError(message: String? = nil, error: Error) {
        showAlert(message: message ?? "Error", informativeText: error.localizedDescription, style: .critical)
    }

    static func showAlert(message: String, informativeText: String? = nil, buttonTitle: String? = nil, secondaryButtonTitle: String? = nil, buttonAction: (() -> Void)? = nil, secondaryButtonAction: (() -> Void)? = nil, primaryIsDestructive: Bool = false, secondaryIsDestructive: Bool = false, style: NSAlert.Style = .informational) {
        let call = {
            let alert = NSAlert()
            alert.alertStyle = style

            alert.messageText = message

            if let informativeText = informativeText {
                alert.informativeText = informativeText
            }

            if let buttonTitle = buttonTitle {
                let primary = alert.addButton(withTitle: buttonTitle)
                primary.hasDestructiveAction = primaryIsDestructive
            }
            if let secondaryButtonTitle = secondaryButtonTitle {
                let secondary = alert.addButton(withTitle: secondaryButtonTitle)
                secondary.hasDestructiveAction = secondaryIsDestructive
            }
            let modalResult = alert.runModal()
            if modalResult.rawValue == 1000 {
                buttonAction?()
            } else {
                secondaryButtonAction?()
            }

        }

        if Thread.isMainThread {
            call()
        } else {
            DispatchQueue.main.async { call() }
        }
    }
}
