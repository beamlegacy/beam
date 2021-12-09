//
//  AppDelegate+BrowserHistoryImport.swift
//  Beam
//
//  Created by Frank Lefebvre on 05/11/2021.
//

import Foundation
import Cocoa
import BeamCore
import Combine

private var subscriptions = Set<AnyCancellable>()

extension AppDelegate {
    @IBAction func importSafariHistory(_ sender: Any) {
        let importer = SafariImporter()
        importHistory(using: importer)
    }

    @IBAction func importFirefoxHistory(_ sender: Any) {
        let importer = FirefoxImporter()
        importHistory(using: importer)
    }

    @IBAction func importChromeHistory(_ sender: Any) {
        let importer = ChromeImporter()
        importHistory(using: importer)
    }

    private func importHistory(using importer: BrowserHistoryImporter) {
        do {
            let frecencyUpdater = BatchFrecencyUpdater(frencencyStore: GRDBUrlFrecencyStorage())
            importer.publisher.sink(receiveCompletion: { [weak frecencyUpdater] completion in
                switch completion {
                case .finished:
                    frecencyUpdater?.saveAll()
                    Logger.shared.logInfo("Import finished successfully", category: .browserImport)
                case .failure(let error):
                    Logger.shared.logError("Import failed with error: \(error)", category: .browserImport)
                }
            }, receiveValue: { [weak frecencyUpdater] result in
                let absoluteString = result.item.url.absoluteString
                let title = result.item.title
                let urlId = LinkStore.shared.getOrCreateIdFor(url: absoluteString, title: title)
                frecencyUpdater?.add(urlId: urlId, date: result.item.timestamp)
                Logger.shared.logDebug("\(result.item.timestamp): \(result.item.title ?? "---") [\(result.item.url)] (total count: \(result.itemCount))")
            }).store(in: &subscriptions)
            try importer.importHistory()
        } catch {
            Logger.shared.logError("Import didn't start: \(error)", category: .browserImport)
        }
    }
}
