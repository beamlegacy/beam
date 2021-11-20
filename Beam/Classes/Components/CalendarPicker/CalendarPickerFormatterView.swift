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

    class ViewModel: BaseFormatterViewViewModel, ObservableObject {
        weak var window: NSWindow?
    }

    static let idealSize = CGSize(width: 240, height: 260)

    @ObservedObject var viewModel: ViewModel = ViewModel()
    @Binding var selectedDate: Date
    var calendar: Calendar
    var body: some View {
        CalendarPickerView(selectedDate: $selectedDate, calendar: calendar, parentWindow: viewModel.window,
                           onPresentSubmenu: { items, point in
                            showContextMenu(items: items, at: point)
                           })
            .background(FormatterViewBackground<EmptyView>())
            .frame(width: Self.idealSize.width)
            .fixedSize(horizontal: false, vertical: true)
            .frame(height: Self.idealSize.height, alignment: .topLeading)
            .animation(BeamAnimation.easeInOut(duration: 0.15))
            .formatterViewBackgroundAnimation(with: viewModel)
    }

    private func showContextMenu(items: [ContextMenuItem], at: CGPoint) {
        let window = viewModel.window
        var point = at
        if let window = window {
            point = at.flippedPointToBottomLeftOrigin(in: window)
        }
        let finalPoint = window?.parent?.convertPoint(fromScreen: window?.convertPoint(toScreen: point) ?? .zero) ?? point
        let subMenuIdentifier = "CalendarSubMenu"
        CustomPopoverPresenter.shared.dismissPopovers(key: subMenuIdentifier)
        let menuView = ContextMenuFormatterView(key: "CalendarSubMenu", items: items, direction: .bottom, sizeToFit: true) {
            CustomPopoverPresenter.shared.dismissPopovers(key: subMenuIdentifier)
        }
        CustomPopoverPresenter.shared.presentFormatterView(menuView, atPoint: finalPoint)
    }
}

// MARK: - NSView Container
class CalendarPickerFormatterView: FormatterView {

    private var hostView: NSHostingView<CalendarPickerFormatterContainerView>?
    private var subviewModel = CalendarPickerFormatterContainerView.ViewModel()
    private var dateHasChanged = false

    override var idealSize: CGSize {
        CalendarPickerFormatterContainerView.idealSize
    }

    var onDateChange: ((Date) -> Void)?
    var onDismiss: ((Bool) -> Void)?
    convenience init() {
        self.init(key: "CalendarPicker", viewType: .inline)
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
        if subviewModel.visible {
            onDismiss?(dateHasChanged)
        }
        subviewModel.visible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.disappearAnimationDuration) {
            completionHandler?()
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        subviewModel.window = newWindow
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
