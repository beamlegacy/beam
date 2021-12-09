//
//  BrowserHistoryImporter.swift
//  Beam
//
//  Created by Frank Lefebvre on 04/11/2021.
//

import Foundation
import Combine
import BeamCore

protocol BrowserHistoryItem {
    var timestamp: Date { get }
    var title: String? { get }
    var url: URL { get }
}

struct BrowserHistoryResult {
    var itemCount: Int
    var item: BrowserHistoryItem
}

protocol BrowserHistoryImporter {
    var publisher: AnyPublisher<BrowserHistoryResult, Error> { get }
    func historyDatabaseURL() throws -> URL?
    func importHistory(from databaseURL: URL) throws
}

extension BrowserHistoryImporter {
    func importHistory() throws {
        try historyDatabaseURL().map { url in
            DispatchQueue.global().async {
                do {
                    try importHistory(from: url)
                } catch {
                    Logger.shared.logError("Import failed with error: \(error)", category: .browserImport)
                }
            }
        }
    }
}
