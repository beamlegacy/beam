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
    private var cancellableScope = [UUID: AnyCancellable]()

    var isImporting: Bool {
        !cancellableScope.isEmpty
    }

    func startBrowserHistoryImport(from importer: BrowserHistoryImporter) {
        let id = UUID()
        do {
            let frecencyUpdater = BatchFrecencyUpdater(frencencyStore: GRDBUrlFrecencyStorage())
            let cancellable = importer.publisher.sink(receiveCompletion: { [weak frecencyUpdater, weak self] completion in
                switch completion {
                case .finished:
                    frecencyUpdater?.saveAll()
                    Logger.shared.logInfo("Import finished successfully", category: .browserImport)
                case .failure(let error):
                    Logger.shared.logError("Import failed with error: \(error)", category: .browserImport)
                }
                self?.cancellableScope.removeValue(forKey: id)
            }, receiveValue: { [weak frecencyUpdater] result in
                let absoluteString = result.item.url.absoluteString
                let title = result.item.title
                let urlId = LinkStore.shared.getOrCreateIdFor(url: absoluteString, title: title)
                frecencyUpdater?.add(urlId: urlId, date: result.item.timestamp)
                Logger.shared.logDebug("\(result.item.timestamp): \(result.item.title ?? "---") [\(result.item.url)] (total count: \(result.itemCount))")
            })
            cancellableScope[id] = cancellable
            try importer.importHistory()
        } catch {
            Logger.shared.logError("Import didn't start: \(error)", category: .browserImport)
            cancellableScope.removeValue(forKey: id)
        }
    }
}
