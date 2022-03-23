//
//  BrowsingTreeStats.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 04/03/2022.
//
import Foundation
import GRDB
import BeamCore

class BrowsingTreeStats: Codable {
    var treeId: UUID
    var createdAt = BeamDate.now
    var updatedAt = BeamDate.now
    var readingTime: Double = 0
    var lifeTime: Double = 0

    init(treeId: UUID) {
        self.treeId = treeId
    }
}
extension BrowsingTreeStats: FetchableRecord {}
extension BrowsingTreeStats: PersistableRecord {}
extension BrowsingTreeStats: TableRecord {
    enum Columns: String, ColumnExpression {
            case treeId, createdAt, updatedAt, readingTime, lifeTime
        }
}
extension BrowsingTreeStats: Identifiable {
    var id: UUID { treeId }
}
