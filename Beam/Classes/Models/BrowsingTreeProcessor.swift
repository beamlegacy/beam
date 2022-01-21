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
    func process(tree: BrowsingTree) {
        Logger.shared.logInfo("Started post sync tree processing: rootId \(tree.root.id)", category: .browsingTreeNetwork)
        let startedAt = BeamDate.now
        tree.root.visit { node in
            guard node.events.count > 0 else { return }
            self.visitFrecencyUpdater.add(urlId: node.link, date: node.events[0].date, eventType: node.visitType)
            self.updateDomainFrecency(updater: self.visitFrecencyUpdater, id: node.link, value: 1.0, date: node.events[0].date)
            switch node.tree.origin {
            case .historyImport: break
            default:
                for segment in node.foregroundSegments {
                    self.readingTimeFrecencyUpdater.add(urlId: node.link, date: segment.start, value: Float(segment.duration), eventType: node.visitType)
                    self.updateDomainFrecency(updater: self.readingTimeFrecencyUpdater, id: node.link, value: Float(segment.duration), date: segment.start)

                }
            }
        }
        visitFrecencyUpdater.saveAll()
        readingTimeFrecencyUpdater.saveAll()
        Logger.shared.logInfo("Completed post sync tree processing: rootId \(tree.root.id)", category: .browsingTreeNetwork, localTimer: startedAt)
    }
}
