//
//  CalendarPickerViewModel.swift
//  Beam
//
//  Created by Remi Santos on 08/07/2021.
//

import Foundation

struct CalendarDay: Hashable {
    let date: Date
    let number: String
    let isSelected: Bool
    let isWithinDisplayedMonth: Bool
}

struct CalendarMonth {
    let numberOfDays: Int
    let firstDay: Date
    let firstDayWeekday: Int
}

extension CalendarPickerView {

    enum CalendarDataError: Error {
        case metadataGeneration
    }

    class Model: ObservableObject {
        var calendar: Calendar

        @Published var baseDate: Date {
            didSet {
                updateData()
            }
        }
        @Published var selectedDate: Date {
            didSet {
                updateData()
            }
        }
        @Published var daysInMonth: [CalendarDay] = []
        @Published var monthInfo: CalendarMonth
        var currentMonth: String {
            monthFormatter.string(from: baseDate)
        }
        var currentYear: String {
            yearFormatter.string(from: baseDate)
        }

        private var daysPerWeek: Int {
            calendar.numberOfDaysInWeek(for: baseDate)
        }

        private var calendarFormatter: DateFormatter {
            let dateFormatter = DateFormatter()
            dateFormatter.calendar = calendar
            return dateFormatter
        }

        private lazy var dayFormatter: DateFormatter = {
            let dateFormatter = calendarFormatter
            dateFormatter.setLocalizedDateFormatFromTemplate("d")
            return dateFormatter
        }()

        private lazy var monthFormatter: DateFormatter = {
            let dateFormatter = calendarFormatter
            dateFormatter.setLocalizedDateFormatFromTemplate("MMMM")
            return dateFormatter
        }()

        private lazy var yearFormatter: DateFormatter = {
            let dateFormatter = calendarFormatter
            dateFormatter.setLocalizedDateFormatFromTemplate("y")
            return dateFormatter
        }()

        init(date: Date, calendar cal: Calendar? = nil) {
            calendar = cal ?? Calendar.current
            selectedDate = date
            baseDate = date
            monthInfo = CalendarMonth(numberOfDays: 0, firstDay: date, firstDayWeekday: calendar.firstWeekday)
            updateData()
        }

        func showPreviousMonth() {
            baseDate = calendar.date(
                byAdding: DateComponents(month: -1),
                to: baseDate) ?? baseDate
        }

        func showNextMonth() {
            baseDate = calendar.date(
                byAdding: DateComponents(month: 1),
                to: baseDate) ?? baseDate
        }

        func showMonth(_ monthIndex: Int) {
            var components = calendar.dateComponents([.day, .month, .year], from: baseDate)
            components.month = monthIndex
            baseDate = calendar.date(from: components) ?? baseDate
        }

        func showYear(_ year: Int) {
            var components = calendar.dateComponents([.month], from: baseDate)
            components.year = year
            baseDate = calendar.date(from: components) ?? baseDate
        }

        private func monthMetadata(for baseDate: Date) throws -> CalendarMonth {
            guard
                let numberOfDaysInMonth = calendar.range(
                    of: .day,
                    in: .month,
                    for: baseDate)?.count,
                let firstDayOfMonth = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: baseDate))
            else {
                throw CalendarPickerView.CalendarDataError.metadataGeneration
            }

            let firstDayWeekday = calendar.component(.weekday, from: firstDayOfMonth)

            return CalendarMonth(
                numberOfDays: numberOfDaysInMonth,
                firstDay: firstDayOfMonth,
                firstDayWeekday: firstDayWeekday)
        }

        private func updateData() {
            guard let monthMetadata = try? monthMetadata(for: baseDate) else {
                fatalError("Calendar Picker - An error occurred when generating the metadata for \(baseDate)")
            }
            monthInfo = monthMetadata
            daysInMonth = generateDaysInMonth(for: monthMetadata)
        }

        private func generateDaysInMonth(for month: CalendarMonth) -> [CalendarDay] {
            let firstDayOfMonth = month.firstDay
            var days: [CalendarDay] = (0..<month.numberOfDays).map { day in
                generateDay(
                    offsetBy: day,
                    for: firstDayOfMonth,
                    isWithinDisplayedMonth: true)
            }
            days.insert(contentsOf: generateEndOfPreviousMonth(using: month), at: 0)
            days += generateStartOfNextMonth(using: firstDayOfMonth)
            return days
        }

        private func generateDay(
            offsetBy dayOffset: Int,
            for baseDate: Date,
            isWithinDisplayedMonth: Bool
        ) -> CalendarDay {
            let date = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: baseDate)
                ?? baseDate

            return CalendarDay(
                date: date,
                number: dayFormatter.string(from: date),
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                isWithinDisplayedMonth: isWithinDisplayedMonth
            )
        }

        private func generateEndOfPreviousMonth(using month: CalendarMonth) -> [CalendarDay] {
            let daysInWeek = daysPerWeek
            let offsetInInitialRow = (month.firstDayWeekday - calendar.firstWeekday + daysInWeek) % daysInWeek
            guard offsetInInitialRow > 0 else { return [] }
            return (1...offsetInInitialRow).map { day in
                generateDay(
                    offsetBy: -day,
                    for: month.firstDay,
                    isWithinDisplayedMonth: false)
            }.reversed()
        }

        private func generateStartOfNextMonth(using firstDayOfDisplayedMonth: Date) -> [CalendarDay] {
            guard let firstDayNextMonth = calendar.date(
                    byAdding: DateComponents(month: 1),
                    to: firstDayOfDisplayedMonth)
            else { return [] }

            let relativeWeekDay = calendar.component(.weekday, from: firstDayNextMonth) - calendar.firstWeekday
            let daysInWeek = daysPerWeek
            let additionalDays = (daysInWeek - relativeWeekDay) % daysInWeek
            guard additionalDays > 0 else { return [] }

            let days: [CalendarDay] = (0..<additionalDays).map {
                generateDay(
                    offsetBy: $0,
                    for: firstDayNextMonth,
                    isWithinDisplayedMonth: false)
            }

            return days
        }
    }
}
