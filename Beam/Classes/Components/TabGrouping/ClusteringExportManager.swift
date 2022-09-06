//
//  ClusteringExportManager.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 23/09/2021.
//

import BeamCore
import Foundation
import os
import Clustering
import NaturalLanguage

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

struct ClusteringExportOrphanedURL: CsvRow {
    let sessionId: UUID
    let url: String?
    let groupId: Int
    let navigationGroupId: Int?
    let savedAt: Date
    let title: String?
    let cleanedContent: String?
    let entities: EntitiesInText?
    let entitiesInTitle: EntitiesInText?
    let language: NLLanguage?

    static var columnNames: [String] {
        ["sessionId", "url", "groupId", "navigationGroupId", "savedAt",
         "title", "cleanedContent", "entities", "entitiesInTitle", "language"]
    }

    var columns: [String] {
        [sessionId.uuidString, optionalToString(url), String(groupId), String(navigationGroupId ?? -1), savedAt.toString, optionalToString(title), optionalToString(cleanedContent), optionalToString(entities?.description), optionalToString(entitiesInTitle?.description), optionalToString(language?.rawValue)]
    }
}

struct ClusteringExportAnyURL: CsvRow {
    var noteName: String?
    var url: String?
    let groupOffsetInClustering: Int?
    var navigationGroupId: Int?
    var tabColouringGroupId: UUID?
    var userCorrectionGroupId: UUID?
    var isGroupCreatedDuringFeedback: Bool = false
    var title: String?
    var cleanedContent: String?
    var entities: EntitiesInText?
    var entitiesInTitle: EntitiesInText?
    let language: NLLanguage?
    let threshold: Float?
    var isOpenAtExport: Bool?
    let id: UUID?
    var parentId: UUID?

    static var columnNames: [String] {
        ["noteName", "url", "groupId", "navigationGroupId",
         "tabColouringGroupId", "userCorrectionGroupId", "isGroupCreatedDuringFeedback",
         "title", "cleanedContent", "entities", "entitiesInTitle", "language",
         "threshold", "isOpenAtExport", "id", "parentId"]
    }

    var columns: [String] {
        [optionalToString(noteName), optionalToString(url), optionalToString(groupOffsetInClustering), String(navigationGroupId ?? -1),
         optionalToString(tabColouringGroupId), optionalToString(userCorrectionGroupId), "\(isGroupCreatedDuringFeedback)",
         optionalToString(title), optionalToString(cleanedContent), optionalToString(entities?.description), optionalToString(entitiesInTitle?.description), optionalToString(language?.rawValue),
         optionalToString(threshold), optionalToString(isOpenAtExport), optionalToString(id), optionalToString(parentId)]
    }
}

class ClusteringSessionExporter {
    var urls: [ClusteringExportAnyURL] = [ClusteringExportAnyURL]()
    let fileManager = FileManager.default
    var gcsManager: GCSObjectManager?

    init() {
        do {
            gcsManager = try GCSObjectManager(bucket: "clustering-beam-exports")
        } catch let err {
            Logger.shared.logError(err.localizedDescription, category: .general)
        }
    }

    func add(anyUrl: ClusteringExportAnyURL) {
        urls.append(anyUrl)
    }

    func export(to: URL, sessionId: UUID, keepFile: Bool) {
        let destination = to.appendingPathComponent("beam_clustering_session-\(sessionId)-\(BeamDate.now).csv")
        let writer = CsvRowsWriter(header: ClusteringExportAnyURL.header, rows: self.urls)
        do {
            try writer.overWrite(to: destination)
            let clusteringVersion = ClusteringType.current.versionRepresentation
            if let gcsManager = gcsManager,
               let email = Persistence.Authentication.email,
               let filename = ("\(clusteringVersion)/\(email)/" + destination.lastPathComponent).addingPercentEncoding(withAllowedCharacters: .alphanumerics) {
                Task {
                    do {
                        _ = try await gcsManager.uploadFile(filename: filename, path: destination)
                        if !keepFile {
                            try fileManager.removeItem(atPath: destination.path)
                        }
                    } catch let err as GCSObjectManagerErrors where err == GCSObjectManagerErrors.disabledService {
                        Logger.shared.logWarning(err.localizedDescription, category: .general)
                    } catch let err {
                        Logger.shared.logError(err.localizedDescription, category: .general)
                    }
                }
            }
        } catch {
            Logger.shared.logError("Unable to save session urls to \(destination)", category: .web)
        }
    }
}

class ClusteringOrphanedUrlManager {
    var urls: [ClusteringExportOrphanedURL] = [ClusteringExportOrphanedURL]()
    var tempURLs: [ClusteringExportOrphanedURL] = [ClusteringExportOrphanedURL]()
    var savePath: URL
    var savePathTemp: URL?
    let fileManager = FileManager.default

    init(savePath: URL) {
        self.savePath = savePath
        self.savePathTemp =  URL(string: savePath.deletingLastPathComponent().string + "temp.csv")
    }

    func add(orphanedUrl: ClusteringExportOrphanedURL) {
        urls.append(orphanedUrl)
    }

    func addTemporarily(orphanedUrl: ClusteringExportOrphanedURL) {
        tempURLs.append(orphanedUrl)
    }

    func save() {
        let writer = CsvRowsWriter(header: ClusteringExportOrphanedURL.header, rows: urls)
        do {
            try writer.append(to: savePath)
        } catch {
            Logger.shared.logError("Couldn't save orphaned urls to \(savePath)", category: .web)
        }
    }

    func export(to: URL) {
        let destination = to.appendingPathComponent("beam_clustering_orphaned_urls-\(BeamDate.now).csv")
        if let savePathTemp = savePathTemp {
            do {
                try FileManager.default.removeItem(at: savePathTemp)
            } catch {
                Logger.shared.logWarning("Did not remove previous temp csv file of orphans from current session", category: .web)
            }
            do {
                try FileManager.default.copyItem(at: savePath, to: savePathTemp)
                let writer = CsvRowsWriter(header: ClusteringExportOrphanedURL.header, rows: tempURLs)
                try writer.append(to: savePathTemp)
                _ = fileManager.secureCopyItem(at: savePathTemp, to: destination)
            } catch {
                Logger.shared.logError("Couldn't add orphans from current session", category: .web)
                _ = fileManager.secureCopyItem(at: savePath, to: destination)
            }
        }
        tempURLs = [ClusteringExportOrphanedURL]()
    }

    func clear() throws {
        if fileManager.fileExists(atPath: self.savePath.path) {
            try fileManager.removeItem(atPath: self.savePath.path)
        }
    }
}
