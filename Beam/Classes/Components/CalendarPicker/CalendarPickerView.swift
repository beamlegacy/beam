//
//  CalendarPickerView.swift
//  Beam
//
//  Created by Remi Santos on 07/07/2021.
//

import SwiftUI

struct CalendarPickerView: View {

    @ObservedObject private var model: CalendarPickerView.Model

    private var selectedDate: Binding<Date>
    init(selectedDate: Binding<Date>, calendar: Calendar? = nil) {
        let model = CalendarPickerView.Model(date: selectedDate.wrappedValue, calendar: calendar)
        self.model = model
        self.selectedDate = selectedDate
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
                              selectedDate: selectedDate.onChange { d in
                                model.selectedDate = d
                              })
        }
        .frame(width: 240, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .background(FormatterViewBackground<EmptyView>())
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
        var atPoint = geometryProxy.frame(in: .global).origin
        let currentMonth = model.calendar.component(.month, from: model.baseDate)
        atPoint.y += CGFloat(currentMonth + 2) * ContextMenuView.itemHeight
        showContextMenu(items: items, at: atPoint)
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
        let frame = geometryProxy.frame(in: .global)
        var atPoint = frame.origin
        atPoint.x = frame.maxX - 60
        atPoint.y += (CGFloat(items.count/2) + 2.5) * ContextMenuView.itemHeight
        showContextMenu(items: items, at: atPoint)
    }

    func showContextMenu(items: [ContextMenuItem], at: CGPoint) {
        let menuView = ContextMenuFormatterView(items: items, direction: .bottom, sizeToFit: true) {
            ContextMenuPresenter.shared.dismissMenu()
        }
        ContextMenuPresenter.shared.presentMenu(menuView, atPoint: at)
    }
}

struct CalendarPickerView_Previews: PreviewProvider {
    static let date = Date()
    static var customCalendar: Calendar {
        var calendar = Calendar(identifier: .hebrew)
        calendar.firstWeekday = 4
        return calendar
    }
    static var previews: some View {
        Group {
            CalendarPickerView(selectedDate: .constant(date))
                .frame(width: 240, alignment: .top)
            CalendarPickerView(selectedDate: .constant(date), calendar: customCalendar)
                .frame(width: 240, alignment: .top)
        }
    }
}
