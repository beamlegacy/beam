//
//  BidirectionalLink.swift
//  Beam
//
//  Created by Sebastien Metrot on 22/06/2021.
//

import Foundation
import GRDB
import BeamCore

/// BidirectionalLink
public struct BidirectionalLink {
    var sourceNoteId: UUID
    var sourceElementId: UUID
    var linkedNoteId: UUID
}

// SQL generation
extension BidirectionalLink: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case sourceNoteId, sourceElementId, linkedNoteId
    }
}

// Fetching methods
extension BidirectionalLink: FetchableRecord {
    /// Creates a record from a database row
    public init(row: Row) {
        sourceElementId = row[Columns.sourceElementId]
        sourceNoteId = row[Columns.sourceNoteId]
        linkedNoteId = row[Columns.linkedNoteId]
    }
}

// Persistence methods
extension BidirectionalLink: MutablePersistableRecord {
    /// The values persisted in the database
    public func encode(to container: inout PersistenceContainer) {
        container[Columns.sourceNoteId] = sourceNoteId
        container[Columns.sourceElementId] = sourceElementId
        container[Columns.linkedNoteId] = linkedNoteId
    }
}

