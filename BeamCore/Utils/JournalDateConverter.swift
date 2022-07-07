//
//  JournalDateConverter.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 27/08/2021.
//

// Default format of journal_date when a string Optional("2021-08-24")
public struct JournalDateConverter {
    public static func toString(from journalDay: Int64) -> String {
        guard journalDay != 0 else { return "0" }

        let day1 = journalDay % 10
        let day2 = (journalDay/10) % 10
        let month1 = (journalDay / 100) % 10
        let month2 = (journalDay / 1000) % 10
        let year = (journalDay / 10000)
        return "\(year)-\(month2)\(month1)-\(day2)\(day1)"
    }

    public static func toInt(from journalDateStr: String) -> Int64 {
        guard let journalDay = Int64(journalDateStr.replacingOccurrences(of: "-", with: "", options: NSString.CompareOptions.literal, range: nil)) else {
            return 0
        }
        return journalDay
    }
}
