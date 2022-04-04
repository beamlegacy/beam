//
//  BrowsingTreeProcessor.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 17/12/2021.
//

import Foundation
import BeamCore

class BrowsingTreeProcessor {
    let visitFrecencyUpdater = BatchFrecencyUpdater(frencencyStore: GRDBUrlFrecencyStorage())
    let readingTimeFrecencyUpdater = BatchFrecencyUpdater(frencencyStore: GRDBUrlFrecencyStorage(), frecencyKey: .webReadingTime30d0)

    private func updateDomainFrecency(updater: BatchFrecencyUpdater, id: UUID, value: Float, date: Date) {
        let isDomain = LinkStore.shared.isDomain(id: id)
        if !isDomain,
            let domainId = LinkStore.shared.getDomainId(id: id) {
            updater.add(urlId: domainId, date: date, value: value, eventType: .webDomainIncrement)
        }
    }
    private func getPreviousMaxImportDate(tree: BrowsingTree) -> Date? {
        switch tree.origin {
        case .historyImport(sourceBrowser: let browserType):
            return Persistence.ImportedBrowserHistory.getMaxDate(for: browserType)
        default: return nil
        }
    }
    private func saveMaxImportDate(date: Date, tree: BrowsingTree) {
        switch tree.origin {
        case .historyImport(sourceBrowser: let browserType):
            Persistence.ImportedBrowserHistory.save(maxDate: date, browserType: browserType)
        default: break
        }
    }
    func process(tree: BrowsingTree) {
        Logger.shared.logInfo("Started post sync tree processing: rootId \(tree.root.id)", category: .browsingTreeNetwork)
        let startedAt = BeamDate.now
        let previousMaxImportDate = getPreviousMaxImportDate(tree: tree) ?? Date.distantPast
        var maxImportDate = Date.distantPast
        tree.root.visit { node in
            guard node.events.count > 0 else { return }
            let date = node.events[0].date
            switch node.tree.origin {
            case .historyImport:
                if date <= previousMaxImportDate { return }
                self.visitFrecencyUpdater.add(urlId: node.link, date: date, eventType: node.visitType)
                self.updateDomainFrecency(updater: self.visitFrecencyUpdater, id: node.link, value: 1.0, date: date)
                if date > maxImportDate { maxImportDate = date}
            default:
                self.visitFrecencyUpdater.add(urlId: node.link, date: date, eventType: node.visitType)
                self.updateDomainFrecency(updater: self.visitFrecencyUpdater, id: node.link, value: 1.0, date: date)
                for segment in node.foregroundSegments {
                    self.readingTimeFrecencyUpdater.add(urlId: node.link, date: segment.start, value: Float(segment.duration), eventType: node.visitType)
                    self.updateDomainFrecency(updater: self.readingTimeFrecencyUpdater, id: node.link, value: Float(segment.duration), date: segment.start)

                }
            }
        }
        visitFrecencyUpdater.saveAll()
        readingTimeFrecencyUpdater.saveAll()
        saveMaxImportDate(date: maxImportDate, tree: tree)
        Logger.shared.logInfo("Completed post sync tree processing: rootId \(tree.root.id)", category: .browsingTreeNetwork, localTimer: startedAt)
    }
}
