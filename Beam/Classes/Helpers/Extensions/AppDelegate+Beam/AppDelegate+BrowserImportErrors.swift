import Foundation
import Combine
import BeamCore

extension AppDelegate {
    func startDisplayingBrowserImportCompletions() {
        data.currentAccount?.data.importsManager.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: self.showError)
            .store(in: &importCancellables)
        data.currentAccount?.data.importsManager.successPublisher
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

extension ImportsManager.ImportSource {
    var description: String {
        switch self {
        case .csv:
            return "CSV file"
        case .browser(let browser):
            return browser.description
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
            switch source {
            case .csv:
                return "The CSV file couldn't be found."
            case .browser(let browser):
                return "The database file from \(browser.description) couldn't be found."
            }
        case .databaseInUse:
            return "Beam can only \(actionDescription) if \(source.description) is closed. Close it and try again."
        case .concurrentImport:
            return "Another import is in progress. Try again later."
        case .keychainError:
            return "Unable to extract the encryption key from the keychain."
        case .invalidFormat:
            return "The database from \(source.description) couldn't be read."
        case .saveError:
            return "Imported data from \(source.description) couldn't be saved."
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
            return "Beam successfully imported your \(count) passwords from \(source.description)."
        case .history:
            return "Beam successfully imported your history from \(source.description)."
        }
    }
}
