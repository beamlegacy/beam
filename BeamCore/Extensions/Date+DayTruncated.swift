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
}

extension Date {
    public var dayTruncated: Date? {
        return MyCalendar.utc?.startOfDay(for: self)
    }
}
