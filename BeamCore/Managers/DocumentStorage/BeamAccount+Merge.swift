//
//  BeamAccount+Merge.swift
//  Beam
//
//  Created by Jérôme Blondon on 23/06/2022.
//

import Foundation
import BeamCore

extension BeamAccount {
    func deleteEmptyDatabases() throws {
        guard let currentDatabase = BeamData.shared.currentDatabase else { return }

        try allDatabases.filter {
            $0.id != currentDatabase.id
        }.forEach { database in
            try database.load()
            let recordCount = database.recordsCount()
            if recordCount == 0 {
                Logger.shared.logInfo("Deleting empty database \(database)", category: .database)
                self.deleteDatabase(database.id)
            }
        }
    }
}
