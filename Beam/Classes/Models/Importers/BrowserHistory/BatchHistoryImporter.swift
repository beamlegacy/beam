//
//  BatchHistoryImporter.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 15/04/2022.
//

import Foundation
import BeamCore

class BeamTimer {
    var durations = [String: Double]()
    func record(stepName: String, block: () -> Void) {
        let start = BeamDate.now
        block()
        let end = BeamDate.now
        durations[stepName] = (durations[stepName] ?? 0) + end.timeIntervalSince(start)
    }
    func log(category: LogCategory) {
        for step in durations.keys {
            Logger.shared.logInfo("\(step): \(durations[step] ?? 0) seconds", category: category)
        }
    }
}

class BatchHistoryImporter {
    let batchSize: Int
    var stepCount: Int = 0

    var maxDate = Date.distantPast
    let timer = BeamTimer()
    let browsingTree: BrowsingTree
    let frecencyUpdater = BatchFrecencyUpdater(frencencyStore: LinkStoreFrecencyUrlStorage(objectManager: BeamData.shared.objectManager))
    let sourceBrowser: BrowserType
    let localLinkStore = LinkStore(linkManager: InMemoryLinkManager())
    let browsingTreeStoreManager: BrowsingTreeStoreManager

    init(sourceBrowser: BrowserType, batchSize: Int = 10_000, browsingTreeStoreManager: BrowsingTreeStoreManager) {
        self.sourceBrowser = sourceBrowser
        self.browsingTree = BrowsingTree(.historyImport(sourceBrowser: sourceBrowser), linkStore: localLinkStore)
        self.batchSize = batchSize
        self.browsingTreeStoreManager = browsingTreeStoreManager
    }

    private func saveBatch() {
        let linksToSave = localLinkStore.allLinks
        LinkStore.shared.insertOrIgnore(links: linksToSave)
        localLinkStore.deleteAll(includedRemote: false) { _ in }
        timer.record(stepName: "frecencySave") {
            frecencyUpdater.saveAll()
        }
    }

    func add(item: BrowserHistoryItem) {

        guard let url = item.url else { return }
        let absoluteString = url.absoluteString
        let title = item.title
        timer.record(stepName: "treeProcessing") {
            browsingTree.addChildToCurrent(url: absoluteString, title: title, date: item.timestamp)
        }
        let urlId = browsingTree.current.link
        timer.record(stepName: "frecencyProcessing") {
            frecencyUpdater.add(urlId: urlId, date: item.timestamp, eventType: .webLinkActivation)
        }
        if item.timestamp > maxDate { maxDate = item.timestamp }
        stepCount += 1
        if stepCount.isMultiple(of: batchSize) {
            saveBatch()
        }
    }

    func finalize(onError: () -> Void ) {
        if !stepCount.isMultiple(of: batchSize) {
            saveBatch()
        }
        timer.record(stepName: "treeSave") {
            do {
                try browsingTreeStoreManager.save(browsingTree: browsingTree)
            } catch {
                Logger.shared.logError("Couldn't save tree: \(error)", category: .browserImport)
                onError()
            }
        }
        Persistence.ImportedBrowserHistory.save(maxDate: maxDate, browserType: sourceBrowser)
        Logger.shared.logInfo("Import finished successfully", category: .browserImport)
        timer.log(category: .browserImport)
        browsingTree.erase() //required to avoid BAD_EXC runtime crash when used in Combine
    }
}
