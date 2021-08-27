//
//  Beam5ToBeam6MigrationPolicy.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 24/08/2021.
//

import Foundation
import CoreData
import BeamCore

@objc class Beam5ToBeam6MigrationPolicy: NSEntityMigrationPolicy {
    func convertJournalDate(forJournalDate: String?) -> Int64 {
        guard let journalDate = forJournalDate else { return 0 }
        return JournalDateConverter.toInt(from: journalDate)
    }
}

