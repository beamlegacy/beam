//
//  ExportAllBrowsingSessions.swift
//  Beam
//
//  Created by Sebastien Metrot on 16/04/2021.
//

import Foundation
import BeamCore

func export_all_browsing_sessions() {
    let docManager = DocumentManager()
    let sessions = docManager.allDocumentsTitles().compactMap({ title -> [BrowsingTree]? in
        guard let note = BeamNote.fetch(docManager, title: title, keepInMemory: false) else { return nil }
        return note.browsingSessions
    }).reduce([], { result, trees -> [BrowsingTree] in
        result + trees
    })

    let encoder = JSONEncoder()

    let fileManager = FileManager.default
    guard let documentDirectory = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
        Logger.shared.logError("Unable to get document direction", category: .web)
        return
    }
    let sessionsFileURL = documentDirectory.appendingPathComponent("beam_all_browsing_sessions \(Date()).json")
    let linksFileURL = documentDirectory.appendingPathComponent("beam_all_links \(Date()).json")

    ////////// Browsing sessions
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
    //swiftlint:disable:next print
    print("All browsing sessions saved to file \(sessionsFileURL)")

    ////////// Links
    guard let linksData = try? encoder.encode(LinkStore.shared.links)
    else {
        Logger.shared.logError("Unable to encode list of links", category: .web)
        return
    }

    do {
        try linksData.write(to: linksFileURL)
    } catch {
        Logger.shared.logError("Unable to save list of browsing sessions", category: .web)
    }
    //swiftlint:disable:next print
    print("All links saved to file \(linksFileURL)")
}
