//
//  CalendarPickerFormatterView.swift
//  Beam
//
//  Created by Remi Santos on 08/07/2021.
//

import Foundation
import SwiftUI
import BeamCore

// MARK: - SwiftUI View

private struct CalendarPickerFormatterContainerView: View {

    class ViewModel: BaseFormatterViewViewModel, ObservableObject { }

    static let idealSize = CGSize(width: 240, height: 260)

    @ObservedObject var viewModel: ViewModel = ViewModel()
    @Binding var selectedDate: Date
    var calendar: Calendar
    var body: some View {
        CalendarPickerView(selectedDate: $selectedDate, calendar: calendar)
            .frame(width: Self.idealSize.width)
            .fixedSize(horizontal: false, vertical: true)
            .frame(height: Self.idealSize.height, alignment: .topLeading)
            .scaleEffect(viewModel.visible ? 1.0 : 0.98)
            .offset(x: 0, y: viewModel.visible ? 0.0 : -4.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6))
            .opacity(viewModel.visible ? 1.0 : 0.0)
            .animation(viewModel.visible ? .easeInOut(duration: 0.3) : .easeInOut(duration: 0.15))
    }
}

// MARK: - NSView Container
class CalendarPickerFormatterView: FormatterView {

    private var hostView: NSHostingView<CalendarPickerFormatterContainerView>?
    private var subviewModel = CalendarPickerFormatterContainerView.ViewModel()
    private var dateHasChanged = false

    override var idealSize: NSSize {
        CalendarPickerFormatterContainerView.idealSize
    }

    var onDateChange: ((Date) -> Void)?
    var onDismiss: ((Bool) -> Void)?
    convenience init() {
        self.init(viewType: .inline)
    }

    override func animateOnAppear(completionHandler: (() -> Void)? = nil) {
        super.animateOnAppear()
        subviewModel.visible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.appearAnimationDuration) {
            completionHandler?()
        }
    }

    override func animateOnDisappear(completionHandler: (() -> Void)? = nil) {
        super.animateOnDisappear()
        subviewModel.visible = false
        onDismiss?(dateHasChanged)
        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.disappearAnimationDuration) {
            completionHandler?()
        }
    }

    private var date = BeamDate.now {
        didSet {
            dateHasChanged = true
        }
    }

    private func updateDate(_ newDate: Date, sendUpdate: Bool) {
        date = newDate
        if sendUpdate {
            onDateChange?(date)
        } else {
            subviewModel.objectWillChange.send()
        }
    }

    private let calendar = Calendar.current

    // MARK: Key Handlers
    override func formatterHandlesCursorMovement(direction: CursorMovement,
                                                 modifierFlags: NSEvent.ModifierFlags? = nil) -> Bool {
        let hasCommand = modifierFlags == .command
        var addition: DateComponents
        let daysPerWeek = calendar.numberOfDaysInWeek(for: date)
        switch direction {
        case .up:
            addition = hasCommand ? DateComponents(month: -1) : DateComponents(day: -daysPerWeek)
        case .down:
            addition = hasCommand ? DateComponents(month: 1) : DateComponents(day: daysPerWeek)
        case .left:
            addition = DateComponents(day: -1)
        case .right:
            addition = DateComponents(day: 1)
        }
        let newDate = calendar.date(byAdding: addition, to: date) ?? date
        updateDate(newDate, sendUpdate: false)
        return true
    }

    override func formatterHandlesEnter() -> Bool {
        onDateChange?(date)
        return true
    }

    // MARK: Private Methods
    override func setupUI() {
        super.setupUI()
        let bindingDate = Binding<Date>(get: { self.date }, set: { self.updateDate($0, sendUpdate: true) })
        let rootView = CalendarPickerFormatterContainerView(viewModel: subviewModel,
                                                            selectedDate: bindingDate,
                                                            calendar: calendar)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
    }
}
