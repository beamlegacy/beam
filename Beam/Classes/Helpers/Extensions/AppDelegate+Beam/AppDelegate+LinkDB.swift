//
//  AppDelegate+LinkDB.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 23/11/2021.
//

import BeamCore
import Foundation

extension AppDelegate {
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
