//
//  BeamDocumentCollection+Helpers.swift
//  Beam
//
//  Created by Sebastien Metrot on 11/05/2022.
//

import Foundation
import BeamCore

public extension BeamDocumentCollection {
    func fetchExists(filters: [DocumentFilter]) throws -> Bool {
        try count(filters: filters) != 0
    }

    func fetchFirst(filters: [DocumentFilter] = [],
                    sortingKey: DocumentSortingKey? = nil) throws -> BeamDocument? {
        return try fetch(filters: [.limit(1, offset: nil)] + filters,
                            sortingKey: sortingKey).first
    }

    func fetchAllWithIds(_ ids: [UUID]) throws -> [BeamDocument] {
        return try fetch(filters: [.ids(ids)])
    }

    func fetchWithId(_ id: UUID) throws -> BeamDocument? {
        return try fetchFirst(filters: [.id(id)])
    }

    func fetchWithTitle(_ title: String) throws -> BeamDocument? {
        return try fetchFirst(filters: [.title(title)], sortingKey: .title(true))
    }

    func fetchWithJournalDate(_ date: String) -> BeamDocument? {
        let date = JournalDateConverter.toInt(from: date)
        return try? fetchFirst(filters: [.journalDate(date)])
    }

    func fetchAllWithTitleMatch(title: String,
                                limit: Int) throws -> [BeamDocument] {
        return try fetch(filters: [.titleMatch(title), .limit(limit, offset: nil)],
                            sortingKey: .title(true))
    }

    // TODO: Merge loadDocumentsWithType and loadAllWithLimit ? Their interface looks pretty similar
    func loadDocumentsWithType(type: DocumentType, _ limit: Int, _ fetchOffset: Int) -> [BeamDocument] {
        do {
            let today = BeamNoteType.titleForDate(BeamDate.now)
            let todayInt = JournalDateConverter.toInt(from: today)

            return try fetch(filters: [.type(type), .nonFutureJournalDate(todayInt), .limit(limit, offset: fetchOffset)], sortingKey: .journal(false))
        } catch { return [] }
    }

    func loadAllWithLimit(_ limit: Int = 4, sortingKey: DocumentSortingKey? = nil, type: DocumentType? = nil) -> [BeamDocument] {
        var filters: [DocumentFilter] = [.limit(limit, offset: nil)]
        if let type = type {
            filters.append(.type(type))
        }
        do {
            return try fetch(filters: filters, sortingKey: sortingKey)
        } catch { return [] }
    }
}
