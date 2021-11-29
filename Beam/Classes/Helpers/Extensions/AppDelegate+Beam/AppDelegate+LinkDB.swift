//
//  AppDelegate+LinkDB.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 23/11/2021.
//

import BeamCore
import Foundation

extension AppDelegate {
    func moveLinkDB() {
        guard let cnt = BeamLinkDB.shared.countLegacy, cnt > 0 else { return }
        let links = BeamLinkDB.shared.allLinksLegacy
        do {
            try GRDBDatabase.shared.insert(links: links)
            try BeamLinkDB.shared.deleteAllLegacy()
        } catch {
            Logger.shared.logError("Couldn't move legacy link db: \(error)", category: .database)
        }

    }

    //TODO: call this function in applicationDidFinishLaunching when links have been moved
    func deleteLegacyDbFile() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: BeamData.linkDBPath) {
            do {
                try fileManager.removeItem(atPath: BeamData.linkDBPath)
            } catch {
                Logger.shared.logError("Couldn't delete legacy link db: \(error)", category: .database)
            }
        }
    }
}
