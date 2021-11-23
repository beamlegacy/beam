//
//  CalendarPickerView.swift
//  Beam
//
//  Created by Remi Santos on 07/07/2021.
//

import SwiftUI
import BeamCore

struct CalendarPickerView: View {

    @ObservedObject private var model: CalendarPickerView.Model

    @Binding private var selectedDate: Date
    private var monthViewTheme: CalendarMonthView.Theme
    private var parentWindow: NSWindow?
    private var onPresentSubmenu: (([ContextMenuItem], CGPoint) -> Void)?

    init(selectedDate: Binding<Date>, highlightedDates: [Date] = [], calendar: Calendar? = nil, theme: CalendarMonthView.Theme = .bluetiful,
         parentWindow: NSWindow?, onPresentSubmenu: (([ContextMenuItem], CGPoint) -> Void)? = nil) {
        let model = CalendarPickerView.Model(date: selectedDate.wrappedValue, calendar: calendar)
        model.highlightedDates = highlightedDates
        self.model = model
        self._selectedDate = selectedDate
        self.parentWindow = parentWindow
        self.monthViewTheme = theme
        self.onPresentSubmenu = onPresentSubmenu
    }

    var headerMonthAndYearView: some View {
        HStack(spacing: 0) {
            ButtonLabel(icon: "nav-back") {
                model.showPreviousMonth()
            }
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ButtonLabel(model.currentMonth, variant: .dropdown) {
                        showMonthContextMenu(geometryProxy: geometry)
                    }
                    Spacer(minLength: 0)
                    ButtonLabel(model.currentYear, variant: .dropdown) {
                        showYearContextMenu(geometryProxy: geometry)
                    }
                }
            }
            ButtonLabel(icon: "nav-forward") {
                model.showNextMonth()
            }
        }
        .padding(.horizontal, BeamSpacing._80)
        .padding(.top, BeamSpacing._100)
        .zIndex(10)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerMonthAndYearView
            Separator(horizontal: true, color: BeamColor.Nero)
                .padding(.horizontal, BeamSpacing._80)
                .padding(.top, BeamSpacing._100)
                .padding(.bottom, BeamSpacing._50)
            CalendarMonthView(calendar: model.calendar,
                              days: model.daysInMonth,
                              baseDate: model.baseDate,
                              selectedDate: $selectedDate.onChange { model.selectedDate = $0 },
                              theme: monthViewTheme)
        }
        .frame(width: 240, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
    }

    func getMonthsContextItems() -> [ContextMenuItem] {
        let months = model.calendar.monthSymbols
        let currentMonth = model.calendar.component(.month, from: model.baseDate) - 1
        return months.enumerated().map { (index, month) in
            ContextMenuItem(title: month, icon: "checkbox-mark", iconPlacement: .leading, iconSize: 10, iconColor: currentMonth == index ? BeamColor.Generic.text : BeamColor.Generic.transparent) {
                model.showMonth(index + 1)
            }
        }
    }

    func showMonthContextMenu(geometryProxy: GeometryProxy) {
        let items = getMonthsContextItems()
        var atPoint = geometryProxy.safeTopLeftGlobalFrame(in: parentWindow).origin
        let currentMonth = model.calendar.component(.month, from: model.baseDate)
        atPoint.y -= CGFloat(currentMonth + 2) * ContextMenuView.itemHeight
        self.onPresentSubmenu?(items, atPoint)
    }

    func getYearsContextItems() -> [ContextMenuItem] {
        let year = model.calendar.component(.year, from: model.baseDate)
        let years = Array(year-6..<year+6)
        return years.map { y in
            ContextMenuItem(title: "\(y)", icon: "checkbox-mark", iconPlacement: .leading, iconSize: 10, iconColor: year == y ? BeamColor.Generic.text : BeamColor.Generic.transparent) {
                model.showYear(y)
            }
        }
    }

    func showYearContextMenu(geometryProxy: GeometryProxy) {
        let items = getYearsContextItems()
        let frame = geometryProxy.safeTopLeftGlobalFrame(in: parentWindow)
        var atPoint = frame.origin
        atPoint.x = frame.maxX - 60
        atPoint.y -= (CGFloat(items.count/2) + 1.5) * ContextMenuView.itemHeight
        self.onPresentSubmenu?(items, atPoint)
    }
}

struct CalendarPickerView_Previews: PreviewProvider {
    static let date = BeamDate.now
    static var customCalendar: Calendar {
        var calendar = Calendar(identifier: .hebrew)
        calendar.firstWeekday = 4
        return calendar
    }
    static var previews: some View {
        Group {
            CalendarPickerView(selectedDate: .constant(date), parentWindow: nil)
                .frame(width: 240, alignment: .top)
            CalendarPickerView(selectedDate: .constant(date), calendar: customCalendar, parentWindow: nil)
                .frame(width: 240, alignment: .top)
        }
    }
}
