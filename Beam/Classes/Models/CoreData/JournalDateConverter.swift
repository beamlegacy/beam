//
//  JournalDateConverter.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 27/08/2021.
//

import BeamCore

// Default format of journal_date when a string Optional("2021-08-24")
struct JournalDateConverter {
    static func toString(from journalDay: Int64) -> String {
        if journalDay == 0 || String(journalDay).count != 8 {
            fatalError("JournalDay: \(journalDay) is incorrect and this should never happen")
        }
        var journalDayStr = String(journalDay)
        journalDayStr.insert("-", at: journalDayStr.index(journalDayStr.startIndex, offsetBy: 4))
        journalDayStr.insert("-", at: journalDayStr.index(journalDayStr.startIndex, offsetBy: 7))
        return journalDayStr
    }

    static func toInt(from journalDateStr: String) -> Int64 {
        guard let journalDay = Int64(journalDateStr.replacingOccurrences(of: "-", with: "", options: NSString.CompareOptions.literal, range: nil)) else {
            return 0
        }
        return journalDay
    }
}
