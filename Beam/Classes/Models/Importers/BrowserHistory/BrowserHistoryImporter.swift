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
    var url: URL? { get }
}

struct BrowserHistoryResult {
    var itemCount: Int
    var item: BrowserHistoryItem
}

protocol BrowserHistoryImporter: BrowserImporter {
    var currentSubject: PassthroughSubject<BrowserHistoryResult, Error>? { get set }
    var publisher: AnyPublisher<BrowserHistoryResult, Error> { get }
    func historyDatabaseURL() throws -> URLProvider?
    func importHistory(from databaseURL: URL, startDate: Date?) throws
    func importHistory(from dbPath: String, startDate: Date?) throws
}

enum BrowserHistoryImporterError: Error {
    case noDatabaseURL
}

extension BrowserHistoryImporter {

    func importHistory(startDate: Date? = nil) throws {
        guard let provider = try historyDatabaseURL() else {
            throw BrowserHistoryImporterError.noDatabaseURL
        }
        DispatchQueue.global().async {
            do {
                try withExtendedLifetime(provider) {
                    try importHistory(from: provider.wrappedURL, startDate: startDate)
                }
            } catch {
                Logger.shared.logError("Import failed with error: \(error)", category: .browserImport)
                currentSubject?.send(completion: .failure(error))
            }
        }
    }
}
