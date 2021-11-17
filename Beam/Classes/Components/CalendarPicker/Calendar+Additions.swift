//
//  Calendar+Additions.swift
//  Beam
//
//  Created by Remi Santos on 17/08/2021.
//

import Foundation

extension Calendar {

    func numberOfDaysInWeek(for date: Date) -> Int {
        // Should always be 7 for the available calendars, but let's not assume anything.
        // https://www.quora.com/Is-there-anywhere-in-the-world-where-a-7-day-week-is-not-observed
        self.range(of: .weekday, in: .weekOfYear, for: date)?.count ?? 0
    }

    func startOfMonth(for date: Date) -> Date? {
        self.date(from: self.dateComponents([.year, .month], from: startOfDay(for: date)))
    }

    func endOfMonth(for date: Date) -> Date? {
        guard let startOfMonth = self.startOfMonth(for: date) else { return nil }
        return self.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
    }
}
