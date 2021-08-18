//
//  Calendar+Calculations.swift
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

}
