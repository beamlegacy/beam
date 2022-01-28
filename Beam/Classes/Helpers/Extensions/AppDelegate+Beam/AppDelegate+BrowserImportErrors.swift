import Foundation
import Combine
import BeamCore

extension AppDelegate {
    func startDisplayingBrowserImportErrors() {
        importErrorCancellable = data.importsManager.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: self.showError)
    }

    func stopDisplayingBrowserImportErrors() {
        importErrorCancellable = nil
    }

    private func showError(_ error: ImportsManager.ImportError) {
        switch error.error {
        case .userCancelled:
            break
        case .fileNotFound:
            UserAlert.showError(message: "\(error.failureDescription): the database file couldn't be found.", informativeText: nil)
        case .databaseInUse:
            UserAlert.showError(message: "Please quit \(error.browser.description).", informativeText: "Beam can only \(error.actionDescription) if \(error.browser.description) is closed. Close it and try again.")
        case .keychainError:
            UserAlert.showError(message: "\(error.failureDescription): unable to extract the encryption key from the keychain.", informativeText: nil)
        case .invalidFormat:
            UserAlert.showError(message: "\(error.failureDescription): the database couldn't be read.", informativeText: nil)
        case .saveError:
            UserAlert.showError(message: "\(error.failureDescription): imported data couldn't be saved.", informativeText: nil)
        case .other(let underlyingError):
            UserAlert.showError(message: "\(error.failureDescription).", error: underlyingError)
        }
    }
}

extension BrowserType {
    var description: String {
        switch self {
        case .safari:
            return "Safari"
        case .chrome:
            return "Google Chrome"
        case .firefox:
            return "Firefox"
        case .brave:
            return "Brave Browser"
        }
    }
}

extension ImportsManager.ImportError {
    var failureDescription: String {
        switch action {
        case .passwords:
            return "Importing \(browser.description) passwords failed"
        case .history:
            return "Importing \(browser.description) history failed"
        }
    }

    var actionDescription: String {
        switch action {
        case .passwords:
            return "import your passwords"
        case .history:
            return "import your history"
        }
    }
}
