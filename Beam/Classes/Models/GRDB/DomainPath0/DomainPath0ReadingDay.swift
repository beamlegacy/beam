//
//  DomainPath0ReadingDay.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 03/03/2022.
//

import Foundation
import GRDB
import BeamCore

struct DomainPath0ReadingDay: Codable {
    var id = UUID()
    let domainPath0: String
    let readingDay: Date
}
extension DomainPath0ReadingDay: FetchableRecord {}
extension DomainPath0ReadingDay: PersistableRecord {}
extension DomainPath0ReadingDay: TableRecord {
    enum Columns: String, ColumnExpression {
            case id, domainPath0, readingDay
        }
}
extension DomainPath0ReadingDay: Identifiable {}
