//
//  ClusteringOrphanedUrlManager.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 23/09/2021.
//

import BeamCore
import Foundation
import os

fileprivate extension FileManager {
    func secureCopyItem(at srcURL: URL, to dstURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                try FileManager.default.removeItem(at: dstURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
        } catch {
            Logger.shared.logError("Cannot copy item at \(srcURL) to \(dstURL): \(error)", category: .general)
            return false
        }
        return true
    }

}

fileprivate extension Date {
    var toString: String {
        let dateFormater = DateFormatter()
        dateFormater.dateFormat = "y-MM-dd H:m:ss.SSS"
        return dateFormater.string(from: self)
    }
}

struct OrphanedUrl: CsvRow {
    let sessionId: UUID
    let url: String?
    let groupId: Int
    let navigationGroupId: Int?
    let savedAt: Date

    static var columnNames: [String] {
        ["sessionId", "url", "groupId", "navigationGroupId", "savedAt"]
    }

    var columns: [String] {
        [sessionId.uuidString, optionalToString(url), String(groupId), String(navigationGroupId ?? -1), savedAt.toString]
    }

}
class ClusteringOrphanedUrlManager {
    var urls: [OrphanedUrl] = [OrphanedUrl]()
    var savePath: URL
    let fileManager = FileManager.default

    init(savePath: URL) {
        self.savePath = savePath
    }

    func add(orphanedUrl: OrphanedUrl) {
        urls.append(orphanedUrl)
    }

    func save() {
        let writer = CsvRowsWriter(header: OrphanedUrl.header, rows: urls)
        do {
            try writer.append(to: savePath)
        } catch {
            Logger.shared.logError("Couldn't save orphaned urls to \(savePath)", category: .web)
        }
    }

    func export(to: URL) {
        let destination = to.appendingPathComponent("beam_clustering_orphaned_urls-\(BeamDate.now).csv")
        _ = fileManager.secureCopyItem(at: savePath, to: destination)
    }

    func clear() throws {
        if fileManager.fileExists(atPath: self.savePath.path) {
            try fileManager.removeItem(atPath: self.savePath.path)
        }
    }
}
