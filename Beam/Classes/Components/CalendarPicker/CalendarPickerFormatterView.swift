//
//  CalendarPickerFormatterView.swift
//  Beam
//
//  Created by Remi Santos on 08/07/2021.
//

import Foundation
import SwiftUI

// MARK: - SwiftUI View

private struct CalendarPickerFormatterContainerView: View {

    class ViewModel: BaseFormatterViewViewModel, ObservableObject { }

    static let idealSize = CGSize(width: 240, height: 220)

    @ObservedObject var viewModel: ViewModel = ViewModel()
    @Binding var selectedDate: Date
    var body: some View {
        CalendarPickerView(selectedDate: $selectedDate)
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

    private var date = Date() {
        didSet {
            dateHasChanged = true
            onDateChange?(date)
        }
    }

    // MARK: Private Methods
    override func setupUI() {
        super.setupUI()
        let bindingDate = Binding<Date>(get: { self.date }, set: { self.date = $0 })
        let rootView = CalendarPickerFormatterContainerView(viewModel: subviewModel, selectedDate: bindingDate)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
    }
}
