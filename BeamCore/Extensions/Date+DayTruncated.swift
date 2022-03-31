//
//  Date+DayTruncated.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 03/03/2022.
//

import Foundation

private class MyCalendar {
    static let utc: Calendar? = {
        guard let utcTimeZone = TimeZone(identifier: "UTC") else { return nil }
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = utcTimeZone
        return calendar
    }()
    static let local = Calendar(identifier: .iso8601)
}

extension Date {
    public var utcDayTruncated: Date? {
        return MyCalendar.utc?.startOfDay(for: self)
    }
    public func localDayString(timeZone: TimeZone? = nil) -> String? {
        var cal = MyCalendar.local
        if let timeZone = timeZone {
            cal = Calendar(identifier: .iso8601)
            cal.timeZone = timeZone
        }
        let components = cal.dateComponents([.year, .month, .day], from: self)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
