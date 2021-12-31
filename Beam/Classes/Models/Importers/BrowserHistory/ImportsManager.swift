//
//  ImportsManager.swift
//  Beam
//
//  Created by Remi Santos on 14/12/2021.
//

import Foundation
import Combine
import BeamCore

public class ImportsManager: NSObject, ObservableObject {
    private var cancellableScope = [UUID: AnyCancellable]() {
        didSet {
            isImporting = !cancellableScope.isEmpty
        }
    }

    @Published var isImporting: Bool = false

    func startBrowserHistoryImport(from importer: BrowserHistoryImporter) {
        let id = UUID()
        do {
            let frecencyUpdater = BatchFrecencyUpdater(frencencyStore: GRDBUrlFrecencyStorage())
            let cancellable = importer.publisher.sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    frecencyUpdater.saveAll()
                    Logger.shared.logInfo("Import History finished successfully", category: .browserImport)
                case .failure(let error):
                    Logger.shared.logError("Import History failed with error: \(error)", category: .browserImport)
                }
                self.cancellableScope.removeValue(forKey: id)
            }, receiveValue: { result in
                guard let url = result.item.url else { return }
                let absoluteString = url.absoluteString
                let title = result.item.title
                let urlId = LinkStore.shared.getOrCreateIdFor(url: absoluteString, title: title)
                frecencyUpdater.add(urlId: urlId, date: result.item.timestamp)
                Logger.shared.logDebug("\(result.item.timestamp): \(result.item.title ?? "---") [\(url)] (total count: \(result.itemCount))")
            })
            cancellableScope[id] = cancellable
            try importer.importHistory()
        } catch {
            Logger.shared.logError("Import didn't start: \(error)", category: .browserImport)
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
                    }
                    self?.cancellableScope.removeValue(forKey: id)
                }, receiveValue: { record in
                    if let hostname = record.item.url.minimizedHost, let password = String(data: record.item.password, encoding: .utf8) {
                        PasswordManager.shared.save(hostname: hostname, username: record.item.username, password: password)
                    } else {
                        Logger.shared.logError("Password could not be imported for \(record.item.username) at \(record.item.url)", category: .browserImport)
                    }
                })
            cancellableScope[id] = cancellable
            try importer.importPasswords()
        } catch {
            Logger.shared.logError("Import didn't start: \(error)", category: .browserImport)
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
}
