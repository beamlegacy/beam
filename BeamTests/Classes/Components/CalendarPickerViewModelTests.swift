//
//  CalendarPickerViewModelTests.swift
//  BeamTests
//
//  Created by Remi Santos on 22/07/2021.
//

import Foundation
import XCTest
import Quick
import Nimble

@testable import Beam

class CalendarPickerViewModelTests: QuickSpec {

    override func spec() {
        var model: CalendarPickerView.Model!
        var baseDate: Date!

        beforeEach {
            var calendar = Calendar(identifier: .gregorian)
            calendar.firstWeekday = 1 // Sunday as first day of week
            let dateComponents = DateComponents(calendar: calendar, year: 2020, month: 6, day: 16) // 16 June 2020 (beam company creation)
            baseDate = calendar.date(from: dateComponents) ?? Date()

            model = CalendarPickerView.Model(date: baseDate, calendar: calendar)
        }

        describe("Setup") {

            it("generates month days on init") {
                let days = model.daysInMonth
                expect(days.count) == 35
                expect(days.first?.number) == "31" // Sun 31 May 2020
                expect(days.last?.number) == "4" // Sat 4 July 2020
                expect(model.baseDate) == baseDate
                expect(model.monthInfo.numberOfDays) == 30
            }

            it("updates days on date change") {
                let newBaseDate = model.calendar.date(from: DateComponents(calendar: model.calendar, year: 2024, month: 2, day: 1))!
                model.baseDate = newBaseDate
                let days = model.daysInMonth
                expect(days.count) == 35
                expect(days.first?.number) == "28" // Sun 29 May 2024
                expect(days.last?.number) == "2" // Sat 2 March 2024
                expect(model.baseDate) == newBaseDate
                expect(model.monthInfo.numberOfDays) == 29
            }

            context("Thursday as firstWeekDay") {
                it("generate month days correctly") {
                    var customCalendar = Calendar(identifier: .gregorian)
                    customCalendar.firstWeekday = 5 // thursday
                    let newModel = CalendarPickerView.Model(date: model.baseDate, calendar: customCalendar)
                    let days = newModel.daysInMonth
                    expect(days.count) == 35
                    expect(days.first?.number) == "28" // Thu 28 May 2020
                    expect(days.last?.number) == "1" // Wed 1 July 2020
                    expect(newModel.baseDate) == baseDate
                    expect(newModel.monthInfo.numberOfDays) == 30
                }
            }
        }

        describe("Selected Date") {
            it("should be the base date") {
                expect(model.selectedDate) == baseDate
                let expectedDay = model.daysInMonth[16]
                expect(expectedDay.date) == baseDate
                expect(expectedDay.number) == "16"
                expect(expectedDay.isSelected) == true
                expect(expectedDay.isWithinDisplayedMonth) == true
            }
            it("update without changing visible days ") {
                expect(model.selectedDate) == baseDate
                let newBaseDate = model.calendar.date(from: DateComponents(calendar: model.calendar, year: 2024, month: 2, day: 1))!
                model.selectedDate = newBaseDate
                let expectedDay = model.daysInMonth[16]
                expect(expectedDay.date) == baseDate
                expect(expectedDay.number) == "16"
                expect(expectedDay.isSelected) == false
            }
        }

        describe("Date change") {
            context("Month") {
                it("shows current") {
                    expect(model.baseDate) == baseDate
                    expect(model.currentMonth) == "June"
                }

                it("can show previous") {
                    expect(model.currentMonth) == "June"
                    model.showPreviousMonth()
                    expect(model.currentMonth) == "May"
                    var newBaseDate = model.calendar.date(from: DateComponents(calendar: model.calendar, year: 2020, month: 5, day: 16))!
                    expect(model.baseDate) == newBaseDate
                    for _ in 0..<5 { // up to previous year
                        model.showPreviousMonth()
                    }
                    newBaseDate = model.calendar.date(from: DateComponents(calendar: model.calendar, year: 2019, month: 12, day: 16))!
                    expect(model.currentMonth) == "December"
                    expect(model.baseDate) == newBaseDate
                }

                it("can show next") {
                    expect(model.currentMonth) == "June"
                    model.showNextMonth()
                    var newBaseDate = model.calendar.date(from: DateComponents(calendar: model.calendar, year: 2020, month: 7, day: 16))!
                    expect(model.currentMonth) == "July"
                    expect(model.baseDate) == newBaseDate
                    for _ in 0..<6 { // up to next year
                        model.showNextMonth()
                    }
                    newBaseDate = model.calendar.date(from: DateComponents(calendar: model.calendar, year: 2021, month: 1, day: 16))!
                    expect(model.currentMonth) == "January"
                    expect(model.baseDate) == newBaseDate
                }

                it("can show any") {
                    expect(model.currentMonth) == "June"
                    model.showMonth(12)
                    let newBaseDate = model.calendar.date(from: DateComponents(calendar: model.calendar, year: 2020, month: 12, day: 16))!
                    expect(model.currentMonth) == "December"
                    expect(model.baseDate) == newBaseDate
                }

            }

            context("Year") {
                it("shows current") {
                    expect(model.baseDate) == baseDate
                    expect(model.currentYear) == "2020"
                }
                it("can show any") {
                    expect(model.currentYear) == "2020"
                    model.showYear(2024)
                    let newBaseDate = model.calendar.date(from: DateComponents(calendar: model.calendar, year: 2024, month: 06, day: 1))!
                    expect(model.currentYear) == "2024"
                    expect(model.baseDate) == newBaseDate
                }
            }

        }
    }

}
