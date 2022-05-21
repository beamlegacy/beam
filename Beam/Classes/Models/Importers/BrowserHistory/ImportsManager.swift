//
//  ImportsManager.swift
//  Beam
//
//  Created by Remi Santos on 14/12/2021.
//

import Foundation
import Combine
import BeamCore
import GRDB
import KeychainAccess

public class ImportsManager: NSObject, ObservableObject {
    enum ImportAction {
        case passwords
        case history
    }

    enum ErrorType {
        case userCancelled
        case fileNotFound
        case databaseInUse
        case concurrentImport
        case keychainError
        case invalidFormat
        case saveError
        case other(underlyingError: Swift.Error)
    }

    struct ImportError: Swift.Error {
        var browser: BrowserType
        var action: ImportAction
        var error: ErrorType
    }

    private var cancellableScope = [UUID: AnyCancellable]() {
        didSet {
            isImporting = !cancellableScope.isEmpty
        }
    }

    @Published var isImporting: Bool = false
    var errorPublisher: AnyPublisher<ImportError, Never>

    private var importErrorSubject: PassthroughSubject<ImportError, Never>

    override init() {
        importErrorSubject = PassthroughSubject<ImportError, Never>()
        errorPublisher = importErrorSubject.eraseToAnyPublisher()
        super.init()
    }

    func startBrowserHistoryImport(from importer: BrowserHistoryImporter) {
        let id = UUID()
        let batchImporter = BatchHistoryImporter(sourceBrowser: importer.sourceBrowser)
        var receivedCount = 0
        let timer = BeamTimer()
        let start = BeamDate.now
        do {
            let cancellable = importer.publisher.sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    batchImporter.finalize {
                        self.sendError(ErrorType.saveError, action: .history, importer: importer)
                    }
                    let end = BeamDate.now
                    Logger.shared.logInfo("Import finished successfully", category: .browserImport)
                    timer.log(category: .browserImport)
                    Logger.shared.logInfo("total: \(end.timeIntervalSince(start)) sec", category: .browserImport)
                case .failure(let error):
                    Logger.shared.logError("Import History failed with error: \(error)", category: .browserImport)
                    self.sendError(error, action: .history, importer: importer)
                }
                self.cancellableScope.removeValue(forKey: id)
            }, receiveValue: { result in
                receivedCount += 1
                if receivedCount.isMultiple(of: 1000) {
                    Logger.shared.logDebug("History import: received \(receivedCount)/\(result.itemCount)", category: .browserImport)
                }
                batchImporter.add(item: result.item)
            })
            cancellableScope[id] = cancellable
            try importer.importHistory(startDate: Persistence.ImportedBrowserHistory.getMaxDate(for: importer.sourceBrowser))
        } catch {
            Logger.shared.logError("Import didn't start: \(error)", category: .browserImport)
            sendError(error, action: .history, importer: importer)
            cancellableScope.removeValue(forKey: id)
        }
    }

    func startBrowserPasswordImport(from importer: BrowserPasswordImporter) {
        let id = UUID()
        do {
            let cancellable = importer.passwordsPublisher
                .sink(receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        Logger.shared.logInfo("Import Password finished successfully", category: .browserImport)
                    case .failure(let error):
                        Logger.shared.logError("Import Password failed with error: \(error)", category: .browserImport)
                        self?.sendError(error, action: .passwords, importer: importer)
                    }
                    self?.cancellableScope.removeValue(forKey: id)
                }, receiveValue: { record in
                    if let hostname = record.item.url.minimizedHost, let password = String(data: record.item.password, encoding: .utf8) {
                        Logger.shared.logDebug("[\(record.itemCount)] Saving password for \(record.item.username) at \(record.item.url)", category: .browserImport)
                        if PasswordManager.shared.save(hostname: hostname, username: record.item.username, password: password) == nil {
                            Logger.shared.logError("Failed to save password for \(record.item.username) at \(record.item.url)", category: .browserImport)
                        }
                    } else {
                        Logger.shared.logError("Password could not be imported for \(record.item.username) at \(record.item.url)", category: .browserImport)
                    }
                })
            cancellableScope[id] = cancellable
            try importer.importPasswords()
        } catch {
            Logger.shared.logError("Import didn't start: \(error)", category: .browserImport)
            sendError(error, action: .passwords, importer: importer)
            cancellableScope.removeValue(forKey: id)
        }
    }

    func startBrowserPasswordImport(from csvURL: URL) {
        do {
            try PasswordImporter.importPasswords(fromCSV: csvURL)
        } catch {
            Logger.shared.logError("Error importing passwords \(String(describing: error))", category: .browserImport)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func sendError(_ error: Swift.Error, action: ImportAction, importer: BrowserImporter) {
        let decodedError: ErrorType
        let cocoaError = error as NSError
        if cocoaError.domain == NSCocoaErrorDomain, cocoaError.code == NSFileNoSuchFileError {
            decodedError = .fileNotFound
        } else if cocoaError.domain == NSCocoaErrorDomain, cocoaError.code == NSUserCancelledError {
            decodedError = .userCancelled
        } else if cocoaError.domain == KeychainAccess.KeychainAccessErrorDomain {
            decodedError = .keychainError
        } else if let error = error as? BrowserHistoryImporterError {
            switch error {
            case .noDatabaseURL:
                decodedError = .userCancelled
            }
        } else if let error = error as? ChromiumPasswordImporter.Error {
            switch error {
            case .noDatabaseURL:
                decodedError = .userCancelled
            case .secretNotFound:
                decodedError = .keychainError
            case .keyDerivationFailed, .unknownPasswordHeader, .decryptionFailed, .countNotAvailable:
                decodedError = .invalidFormat
            }
        } else if let error = error as? GRDB.DatabaseError, error.resultCode == .SQLITE_BUSY {
            decodedError = .databaseInUse
        } else if error is ExclusiveRunner.Error {
            decodedError = .concurrentImport
        } else {
            decodedError = .other(underlyingError: error)
        }
        sendError(decodedError, action: action, importer: importer)
    }

    private func sendError(_ decodedError: ErrorType, action: ImportAction, importer: BrowserImporter) {
        let importError = ImportError(browser: importer.sourceBrowser, action: action, error: decodedError)
        importErrorSubject.send(importError)
    }
}
