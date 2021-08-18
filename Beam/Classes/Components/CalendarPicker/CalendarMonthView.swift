//
//  CalendarMonthView.swift
//  Beam
//
//  Created by Remi Santos on 08/07/2021.
//

import Foundation
import SwiftUI

private struct WeekDay: Identifiable {
    var id: String { name }
    var name: String
}

struct CalendarMonthView: View {

    var calendar: Calendar
    var days: [CalendarDay]
    var baseDate: Date
    @Binding var selectedDate: Date
    @State private var hoveredDate: Date?
    @State private var touchdownDate: Date?

    private var weekDays: [WeekDay] {
        let alldays: [WeekDay] = calendar.weekdaySymbols.map { symbol in
            let dayName = String(symbol.prefix(2))
            return WeekDay(name: dayName)
        }
        // shift for first weekday != sunday (-1 because weekdays start at 1)
        let firstWeekday = calendar.firstWeekday - 1
        return Array(alldays[firstWeekday...]) + Array(alldays[..<firstWeekday])
    }

    private var daysPerWeek: Int {
        calendar.numberOfDaysInWeek(for: baseDate)
    }

    private var numberOfWeeksToShow: Int {
        Int(days.count / daysPerWeek)
    }

    fileprivate func dayOfWeekView(_ day: WeekDay) -> some View {
        Text(day.name)
            .foregroundColor(BeamColor.AlphaGray.swiftUI)
            .font(BeamFont.medium(size: 11).swiftUI)
            .overlay(Rectangle()
                        .fill(BeamColor.Mercury.swiftUI)
                        .frame(height: 1)
                        .offset(x: 0, y: 2), alignment: .bottom)
            .frame(maxWidth: .infinity)
            .padding([.horizontal, .top], 3)
            .padding(.bottom, 6)
    }

    fileprivate func dayView(_ day: CalendarDay) -> some View {
        var color = day.isWithinDisplayedMonth ? BeamColor.Niobium : BeamColor.AlphaGray
        var font = BeamFont.regular(size: 13)
        if day.isSelected {
            color = BeamColor.Bluetiful
            font = BeamFont.medium(size: 13)
        }
        let isHovering = hoveredDate == day.date
        let isTouchDown = touchdownDate == day.date
        var backgroundColor: BeamColor?
        if isTouchDown {
            backgroundColor = day.isSelected ? BeamColor.CalendarPicker.selectedDayClickedBackground : BeamColor.CalendarPicker.dayClickedBackground
        } else if isHovering {
            backgroundColor = day.isSelected ? BeamColor.CalendarPicker.selectedDayHoverBackground : BeamColor.CalendarPicker.dayHoverBackground
        } else if day.isSelected {
            backgroundColor = BeamColor.CalendarPicker.selectedDayBackground
        }
        return Text(day.number)
            .foregroundColor(color.swiftUI)
            .font(font.swiftUI)
            .padding(3)
            .frame(maxWidth: .infinity)
            .background(backgroundColor != nil ?
                            Rectangle()
                            .fill(backgroundColor?.swiftUI ?? Color.clear)
                            .frame(width: 22, height: 22)
                            .cornerRadius(3)
                            : nil
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedDate = day.date
            }
            .onHover { hovering in
                if hovering {
                    hoveredDate = day.date
                } else if hoveredDate == day.date {
                    hoveredDate = nil
                }
            }
            .onTouchDown { touchdown in
                if touchdown {
                    touchdownDate = day.date
                } else if touchdownDate == day.date {
                    touchdownDate = nil
                }
            }
    }

    private func daysInWeek(weekIndex: Int, numberOfWeeks: Int) -> [CalendarDay] {
        let startIndex = min(days.count - 1, weekIndex * daysPerWeek)
        let endIndex = min(days.count, startIndex+daysPerWeek)
        return Array(days[startIndex..<endIndex])
    }

    var body: some View {
        VStack(spacing: 0) {
            let nbrWeeks = numberOfWeeksToShow
            HStack(spacing: 0) {
                ForEach(weekDays) { day in
                    dayOfWeekView(day)
                }
            }
            ForEach(0..<nbrWeeks, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    let daysOfWeek = daysInWeek(weekIndex: weekIndex, numberOfWeeks: nbrWeeks)
                    ForEach(daysOfWeek, id: \.self) { day in
                        dayView(day)
                    }
                }
                .padding(.vertical, BeamSpacing._40)
            }
            Spacer()
        }
        .padding(.horizontal, BeamSpacing._80)
        .padding(.bottom, BeamSpacing._50)
    }
}
