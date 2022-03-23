//
//  DomainPath0TreeStats.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 03/03/2022.
//

import Foundation
import GRDB
import BeamCore

struct DomainPath0TreeStats: Codable {
    var id = UUID()
    var createdAt = BeamDate.now
    var updatedAt = BeamDate.now
    let treeId: UUID
    let domainPath0: String
    var readingTime: Double = 0
}
extension DomainPath0TreeStats: FetchableRecord {}
extension DomainPath0TreeStats: PersistableRecord {}
extension DomainPath0TreeStats: TableRecord {
    enum Columns: String, ColumnExpression {
            case id, createdAt, updatedAt, treeId, domainPath0, readingTime
        }
}
extension DomainPath0TreeStats: Identifiable {}
