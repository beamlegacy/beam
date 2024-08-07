//
//  ExportAllBrowsingSessions.swift
//  Beam
//
//  Created by Sebastien Metrot on 16/04/2021.
//

import Foundation
import BeamCore

func export_all_browsing_sessions(_ treeManager: BrowsingTreeStoreManager, to url: URL?) {
    guard let url = url else { return }

    guard let sessions = try? treeManager.getAllBrowsingTrees() else {
        Logger.shared.logError("Could not fetch browsing sessions", category: .web)
        return
    }

    let encoder = JSONEncoder()

    let sessionsFileURL = url.appendingPathComponent("beam_all_browsing_sessions \(BeamDate.now).json")
    let linksFileURL = url.appendingPathComponent("beam_all_links \(BeamDate.now).json")

    // MARK: Browsing sessions
    guard let sessionsData = try? encoder.encode(sessions)
    else {
        Logger.shared.logError("Unable to encode list of browsing sessions", category: .web)
        return
    }

    do {
        try sessionsData.write(to: sessionsFileURL)
    } catch {
        Logger.shared.logError("Unable to save list of browsing sessions to \(sessionsFileURL)", category: .web)
    }
    print("All browsing sessions saved to file \(sessionsFileURL)")

    // MARK: Links
    guard let linksData = try? encoder.encode(LinkStore.shared.allLinks)
    else {
        Logger.shared.logError("Unable to encode list of links", category: .web)
        return
    }

    do {
        try linksData.write(to: linksFileURL)
    } catch {
        Logger.shared.logError("Unable to save list of browsing sessions", category: .web)
    }
    print("All links saved to file \(linksFileURL)")
}
