//
//  MeetingFormatterView.swift
//  Beam
//
//  Created by Remi Santos on 05/10/2021.
//

import Foundation
import SwiftUI
import BeamCore
import Combine

// MARK: - SwiftUI View
private struct MeetingFormatterContainerView: View {

    class ViewModel: BaseFormatterViewViewModel, ObservableObject {
        @Published var searchText: String = ""
        @Published var selectedDate: Date = .init()
        @Published var allMeetingDates: [Date] = []
        @Published var meetingsByDay: [MeetingsForDay] = [] {
            didSet {
                allMeetingDates = meetingsByDay.reduce([Date](), { result, meetingsForDay in
                    result + meetingsForDay.meetings.map { $0.date }
                })
            }
        }
        @Published var selectedMeeting: Meeting?

        var onSelectMeeting: ((_ meeting: Meeting) -> Void)?
        weak var window: NSWindow?
    }

    static let idealSize = CGSize(width: 484, height: 260)

    @ObservedObject var viewModel: ViewModel = ViewModel()
    var calendar: Calendar

    struct BlinkingCursor: View {
        @State private var blinking = false

        var body: some View {
            RoundedRectangle(cornerRadius: 1)
                .fill(BeamColor.Generic.text.swiftUI)
                .frame(width: 8, height: 21)
                .opacity(blinking ? 0 : 1)
                .animation(BeamAnimation.easeInOut(duration: 0.2).delay(0.5).repeatForever(autoreverses: true), value: blinking)
                .onAppear { blinking = true }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {

            if viewModel.visible {
                HStack(spacing: 3) {
                    Icon(name: "editor-calendar", size: 16, color: BeamColor.Beam.swiftUI)
                    Text("Meeting")
                        .font(BeamFont.regular(size: 14).swiftUI)
                        .foregroundColor(BeamColor.Beam.swiftUI)
                    Separator(color: BeamColor.Beam)
                        .frame(height: 15)
                        .padding(.leading, 2)
                        .padding(.trailing, 5)
                    ZStack(alignment: .trailing) {
                        Text(viewModel.searchText + " ")
                            .font(BeamFont.regular(size: 15).swiftUI)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .padding(.trailing, 3)
                        BlinkingCursor()
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                .background(BeamColor.Generic.background.swiftUI
                                .overlay(BeamColor.Beam.swiftUI.opacity(0.1))
                                .cornerRadius(4))
                .transition(.opacity.animation(BeamAnimation.easeInOut(duration: 0.15)))
            }
            HStack(spacing: 0) {
                MeetingsListView(meetingsByDay: viewModel.meetingsByDay, selectedMeeting: $viewModel.selectedMeeting.onChange({ m in
                    guard let m = m else { return }
                    viewModel.onSelectMeeting?(m)
                }), searchQuery: viewModel.searchText)
                    .animation(nil)
                Separator(color: BeamColor.Nero)
                CalendarPickerView(selectedDate: $viewModel.selectedDate, highlightedDates: viewModel.allMeetingDates, calendar: calendar, theme: .beam) { items, point in
                    showContextMenu(items: items, at: point)
                }
            }
            .background(FormatterViewBackground<EmptyView>())
            .frame(width: Self.idealSize.width)
            .fixedSize(horizontal: false, vertical: true)
            .frame(height: Self.idealSize.height, alignment: .topLeading)
            .animation(BeamAnimation.easeInOut(duration: 0.15))
            .formatterViewBackgroundAnimation(with: viewModel)
        }
    }

    func showContextMenu(items: [ContextMenuItem], at: CGPoint) {
        let window = viewModel.window
        let finalPoint = window?.parent?.convertPoint(fromScreen: window?.convertPoint(toScreen: at) ?? .zero) ?? at
        let subMenuIdentifier = "CalendarSubMenu"
        CustomPopoverPresenter.shared.dismissPopovers(key: subMenuIdentifier)
        let menuView = ContextMenuFormatterView(key: "CalendarSubMenu", items: items, direction: .bottom, sizeToFit: true) {
            CustomPopoverPresenter.shared.dismissPopovers(key: subMenuIdentifier)
        }
        CustomPopoverPresenter.shared.presentFormatterView(menuView, atPoint: finalPoint)
    }
}

// MARK: - NSView Container
class MeetingFormatterView: FormatterView {

    private var hostView: NSHostingView<MeetingFormatterContainerView>?
    private var subviewModel = MeetingFormatterContainerView.ViewModel()
    private var dateObserver: AnyCancellable?

    override var idealSize: CGSize {
        MeetingFormatterContainerView.idealSize
    }
    override var handlesTyping: Bool { true }

    private var sentFinish = false
    var onFinish: ((_ meeting: Meeting?) -> Void)?

    convenience init() {
        self.init(key: "MeetingPicker", viewType: .inline)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        subviewModel.window = newWindow
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
        if !sentFinish {
            onFinish?(nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.disappearAnimationDuration) {
            completionHandler?()
        }
    }

    private func searchMeeting(for date: Date) {
        subviewModel.meetingsByDay = fakeResults(for: date)
        subviewModel.selectedMeeting = subviewModel.meetingsByDay.first?.meetings.first
    }

    private func searchMeeting(for text: String) {
        subviewModel.searchText = text
        subviewModel.meetingsByDay = text.isEmpty ? fakeResults(for: BeamDate.now) : searchFakeResults
        subviewModel.selectedMeeting = subviewModel.meetingsByDay.first?.meetings.first
    }

    private let calendar = Calendar.current

    // MARK: Key Handlers
    override func formatterHandlesCursorMovement(direction: CursorMovement,
                                                 modifierFlags: NSEvent.ModifierFlags? = nil) -> Bool {
        let allMeetings: [Meeting] = subviewModel.meetingsByDay.reduce([Meeting]()) { meetings, meetingForDay in
            return meetings + meetingForDay.meetings
        }
        var absoluteMeetingIndex: Int = subviewModel.selectedMeeting == nil ? 0 : allMeetings.firstIndex { $0.id == subviewModel.selectedMeeting?.id } ?? 0
        switch direction {
        case .up:
            absoluteMeetingIndex -= 1
        case .down:
            absoluteMeetingIndex += 1
        default:
            break
        }
        absoluteMeetingIndex = absoluteMeetingIndex.clamp(0, allMeetings.count - 1)
        subviewModel.selectedMeeting = allMeetings[absoluteMeetingIndex]
        return true
    }

    override func formatterHandlesEnter() -> Bool {
        guard let meeting = subviewModel.selectedMeeting else { return false }
        onFinish?(meeting)
        return true
    }

    override func formatterHandlesInputText(_ text: String) -> Bool {
        guard !text.isEmpty || !subviewModel.searchText.isEmpty else { return false } // delete backward
        searchMeeting(for: text)
        return true
    }

    // MARK: Private Methods
    override func setupUI() {
        super.setupUI()
        subviewModel.selectedDate = BeamDate.now
        subviewModel.selectedMeeting = selectedMeeting(for: BeamDate.now)
        subviewModel.meetingsByDay = fakeResults(for: BeamDate.now)
        subviewModel.onSelectMeeting = { [weak self] meeting in
            self?.onFinish?(meeting)
        }
        dateObserver = subviewModel.$selectedDate.sink { [weak self] newDate in
            self?.searchMeeting(for: newDate)
        }
        let rootView = MeetingFormatterContainerView(viewModel: subviewModel, calendar: calendar)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
    }

    private let selectedMeetingUUID = UUID()

}

// MARK: - Fake Meetings Data
extension MeetingFormatterView {

    private func selectedMeeting(for date: Date) -> Meeting {
        Meeting(id: selectedMeetingUUID, name: "Yeah sure", startTime: BeamDate.now, date: date, attendees: [])
    }

    private func fakeResults(for date: Date) -> [MeetingsForDay] { [
        MeetingsForDay(date: date, meetings: [
            selectedMeeting(for: date.addingTimeInterval(2000)),
            Meeting(name: "Yeah sure \(calendar.dateComponents([.day], from: date).day!)-\(calendar.dateComponents([.month], from: date).month!)", startTime: BeamDate.now, date: date.addingTimeInterval(6000), attendees: []),
            Meeting(name: "Ouiiiii", startTime: BeamDate.now, date: BeamDate.now.addingTimeInterval(20000), attendees: [])
        ])
    ] }

    private var searchFakeResults: [MeetingsForDay] { [
        MeetingsForDay(date: BeamDate.now.addingTimeInterval(150000), meetings: [
            Meeting(name: "Malaga retreat", startTime: BeamDate.now, date: BeamDate.now.addingTimeInterval(10000), attendees: [
                .init(email: "john@beamapp.co", name: "John Begood"),
                .init(email: "dam@beamapp.co", name: "Dam Dam")
            ])
        ]),
        MeetingsForDay(date: BeamDate.now.addingTimeInterval(300000), meetings: [
            Meeting(name: "Something in the future", startTime: BeamDate.now, date: BeamDate.now.addingTimeInterval(150000), attendees: [])
        ])
    ] }
}
