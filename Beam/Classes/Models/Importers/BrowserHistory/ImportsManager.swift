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
    enum ImportSource {
        case csv
        case browser(BrowserType)
    }

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
        var source: ImportSource
        var action: ImportAction
        var error: ErrorType
    }

    struct ImportSuccess {
        var source: ImportSource
        var action: ImportAction
        var count: Int
    }

    private var cancellableScope = [UUID: AnyCancellable]() {
        didSet {
            isImporting = !cancellableScope.isEmpty
        }
    }

    @Published var isImporting: Bool = false
    var errorPublisher: AnyPublisher<ImportError, Never>
    var successPublisher: AnyPublisher<ImportSuccess, Never>

    private var importErrorSubject: PassthroughSubject<ImportError, Never>
    private var importSuccessSubject: PassthroughSubject<ImportSuccess, Never>

    override init() {
        importErrorSubject = PassthroughSubject<ImportError, Never>()
        importSuccessSubject = PassthroughSubject<ImportSuccess, Never>()
        errorPublisher = importErrorSubject.eraseToAnyPublisher()
        successPublisher = importSuccessSubject.eraseToAnyPublisher()
        super.init()
    }

    func startBrowserHistoryImport(from importer: BrowserHistoryImporter) {
        let id = UUID()
        let batchImporter = BatchHistoryImporter(sourceBrowser: importer.sourceBrowser)
        do {
            var receivedCount = 0
            let timer = BeamTimer()
            let start = BeamDate.now
            let cancellable = importer.publisher.sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                switch completion {
                case .finished:
                    batchImporter.finalize {
                        self.sendError(ErrorType.saveError, action: .history, source: .browser(importer.sourceBrowser))
                    }
                    let end = BeamDate.now
                    self.sendSuccess(action: .history, source: .browser(importer.sourceBrowser), count: receivedCount)
                    Logger.shared.logInfo("Import finished successfully", category: .browserImport)
                    timer.log(category: .browserImport)
                    Logger.shared.logInfo("total: \(end.timeIntervalSince(start)) sec", category: .browserImport)
                case .failure(let error):
                    Logger.shared.logError("Import History failed with error: \(error)", category: .browserImport)
                    self.sendError(error, action: .history, source: .browser(importer.sourceBrowser))
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
            try importer.importHistory(startDate: Persistence.ImportedBrowserHistory.getMaxDate(for: importer.sourceBrowser)) { _ in }
        } catch {
            Logger.shared.logError("Import didn't start: \(error)", category: .browserImport)
            sendError(error, action: .history, source: .browser(importer.sourceBrowser))
            cancellableScope.removeValue(forKey: id)
        }
    }

    func startBrowserPasswordImport(from importer: BrowserPasswordImporter) {
        let id = UUID()
        do {
            var importedCount = 0
            let cancellable = importer.passwordsPublisher
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    switch completion {
                    case .finished:
                        Logger.shared.logInfo("Import Password finished successfully", category: .browserImport)
                        self.sendSuccess(action: .passwords, source: .browser(importer.sourceBrowser), count: importedCount)
                    case .failure(let error):
                        Logger.shared.logError("Import Password failed with error: \(error)", category: .browserImport)
                        self.sendError(error, action: .passwords, source: .browser(importer.sourceBrowser))
                    }
                    self.cancellableScope.removeValue(forKey: id)
                }, receiveValue: { record in
                    if let hostname = record.item.url.minimizedHost, let password = String(data: record.item.password, encoding: .utf8) {
                        Logger.shared.logDebug("[\(record.itemCount)] Saving password for \(record.item.username) at \(record.item.url)", category: .browserImport)
                        if PasswordManager.shared.save(hostname: hostname, username: record.item.username, password: password) == nil {
                            Logger.shared.logError("Failed to save password for \(record.item.username) at \(record.item.url)", category: .browserImport)
                        } else {
                            importedCount += 1
                        }
                    } else {
                        Logger.shared.logError("Password could not be imported for \(record.item.username) at \(record.item.url)", category: .browserImport)
                    }
                })
            cancellableScope[id] = cancellable
            try importer.importPasswords { _ in }
        } catch {
            Logger.shared.logError("Import didn't start: \(error)", category: .browserImport)
            sendError(error, action: .passwords, source: .browser(importer.sourceBrowser))
            cancellableScope.removeValue(forKey: id)
        }
    }

    func startBrowserPasswordImport(from csvURL: URL) {
        do {
            let importedCount = try PasswordImporter.importPasswords(fromCSV: csvURL)
            sendSuccess(action: .passwords, source: .csv, count: importedCount)
        } catch {
            Logger.shared.logError("Error importing passwords \(String(describing: error))", category: .browserImport)
            sendError(error, action: .passwords, source: .csv)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func sendError(_ error: Swift.Error, action: ImportAction, source: ImportSource) {
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
        sendError(decodedError, action: action, source: source)
    }

    private func sendError(_ decodedError: ErrorType, action: ImportAction, source: ImportSource) {
        let importError = ImportError(source: source, action: action, error: decodedError)
        importErrorSubject.send(importError)
    }

    private func sendSuccess(action: ImportAction, source: ImportSource, count: Int) {
        guard count != 0 else { return }
        let importSuccess = ImportSuccess(source: source, action: action, count: count)
        importSuccessSubject.send(importSuccess)
    }
}
