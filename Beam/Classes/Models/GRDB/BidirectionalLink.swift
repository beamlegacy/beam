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
public struct BidirectionalLink: Equatable {
    var id: Int64?
    var sourceNoteId: UUID
    var sourceElementId: UUID
    var linkedNoteId: UUID
}

// SQL generation
extension BidirectionalLink: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, sourceNoteId, sourceElementId, linkedNoteId
    }
}

// Fetching methods
extension BidirectionalLink: FetchableRecord {
    /// Creates a record from a database row
    public init(row: Row) {
        id = row[Columns.id]
        sourceElementId = row[Columns.sourceElementId]
        sourceNoteId = row[Columns.sourceNoteId]
        linkedNoteId = row[Columns.linkedNoteId]
    }
}

// Persistence methods
extension BidirectionalLink: MutablePersistableRecord {
    /// The values persisted in the database
    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.sourceNoteId] = sourceNoteId
        container[Columns.sourceElementId] = sourceElementId
        container[Columns.linkedNoteId] = linkedNoteId
    }

    // Update auto-incremented id upon successful insertion
    public mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

public extension BidirectionalLink {
    var reference: BeamNoteReference {
        return BeamNoteReference(noteID: sourceNoteId, elementID: sourceElementId)
    }

    var linkedNote: BeamNote? {
        BeamNote.fetch(id: linkedNoteId)
    }

    var sourceNote: BeamNote? {
        BeamNote.fetch(id: sourceNoteId)
    }

    var sourceElement: BeamElement? {
        return sourceNote?.findElement(sourceElementId)
    }
}
