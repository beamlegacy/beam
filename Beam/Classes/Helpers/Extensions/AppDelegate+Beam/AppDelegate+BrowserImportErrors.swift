import Foundation
import Combine
import BeamCore

extension AppDelegate {
    func startDisplayingBrowserImportCompletions() {
        data.importsManager.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: self.showError)
            .store(in: &importCancellables)
        data.importsManager.successPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: self.showSuccess)
            .store(in: &importCancellables)
    }

    func stopDisplayingBrowserImportErrors() {
        importCancellables.removeAll()
    }

    private func showError(_ error: ImportsManager.ImportError) {
        switch error.error {
        case .userCancelled:
            break
        case .other(let underlyingError):
            UserAlert.showError(message: error.failureDescription, error: underlyingError)
        default:
            UserAlert.showError(message: error.failureDescription, informativeText: error.failureInformation)
        }
    }

    private func showSuccess(_ operation: ImportsManager.ImportSuccess) {
        UserAlert.showMessage(message: operation.successDescription, informativeText: operation.successInformation)
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
            return "Passwords Import Failure"
        case .history:
            return "History Import Failure"
        }
    }

    var failureInformation: String {
        switch error {
        case .userCancelled, .other:
            return "" // handled separately
        case .fileNotFound:
            return "The database file from \(browser.description) couldn't be found."
        case .databaseInUse:
            return "Beam can only \(actionDescription) if \(browser.description) is closed. Close it and try again."
        case .concurrentImport:
            return "Another import is in progress. Try again later."
        case .keychainError:
            return "Unable to extract the encryption key from the keychain."
        case .invalidFormat:
            return "The database from \(browser.description) couldn't be read."
        case .saveError:
            return "Imported data from \(browser.description) couldn't be saved."
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

extension ImportsManager.ImportSuccess {
    var successDescription: String {
        switch action {
        case .passwords:
            return "Passwords Import Success"
        case .history:
            return "History Import Success"
        }
    }

    var successInformation: String {
        switch action {
        case .passwords:
            return "Beam successfully imported your \(count) passwords from \(browser.description)."
        case .history:
            return "Beam successfully imported your history from \(browser.description)."
        }
    }
}
