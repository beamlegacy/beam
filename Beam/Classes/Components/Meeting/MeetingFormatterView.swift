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
        @Published var isLoading = false
        @Published var meetingsByDay: [MeetingsForDay] = [] {
            didSet {
                allMeetingDates = Array(meetingsByDay.reduce(Set<Date>(), { result, meetingsForDay in
                    var r = result
                    meetingsForDay.meetings.forEach { r.insert($0.startTime) }
                    return r
                }))
            }
        }
        @Published var selectedMeeting: Meeting? {
            didSet {
                if let id = selectedMeeting?.id {
                    scrollViewProxy?.scrollTo(id)
                }
            }
        }

        var onSelectMeeting: ((_ meeting: Meeting) -> Void)?
        weak var window: NSWindow?
        fileprivate var scrollViewProxy: ScrollViewProxy?
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
                ZStack(alignment: .topLeading) { }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    // putting scrollview in zstack background to not let its height influence the container height.
                    ScrollView {
                        ScrollViewReader { proxy in
                            MeetingsListView(meetingsByDay: viewModel.meetingsByDay, selectedMeeting: $viewModel.selectedMeeting.onChange({ m in
                                guard let m = m else { return }
                                viewModel.onSelectMeeting?(m)
                            }), searchQuery: viewModel.searchText, isLoading: viewModel.isLoading)
                                .animation(nil)
                                .onAppear {
                                    viewModel.scrollViewProxy = proxy
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
                Separator(color: BeamColor.Nero)
                CalendarPickerView(selectedDate: $viewModel.selectedDate, highlightedDates: viewModel.allMeetingDates,
                                   calendar: calendar, theme: .beam, parentWindow: viewModel.window) { items, point in
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

    private var calendarManager: CalendarManager
    private var hostView: NSHostingView<MeetingFormatterContainerView>?
    private var subviewModel = MeetingFormatterContainerView.ViewModel()
    private var dateObserver: AnyCancellable?
    private let calendar = Calendar.current
    private weak var todaysNote: BeamNote?

    override var idealSize: CGSize {
        MeetingFormatterContainerView.idealSize
    }
    override var handlesTyping: Bool { true }

    var onFinish: ((_ meeting: Meeting?) -> Void)?

    init(calendarManager: CalendarManager, todaysNote: BeamNote?) {
        self.todaysNote = todaysNote
        self.calendarManager = calendarManager
        super.init(key: "MeetingPicker", viewType: .inline)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        if subviewModel.visible {
            onFinish?(nil)
        }
        subviewModel.visible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.disappearAnimationDuration) {
            completionHandler?()
        }
    }

    private func groupMeetingsByDay(_ meetings: [Meeting]) -> [MeetingsForDay] {
        var dic: [Date: MeetingsForDay] = [:]
        meetings.forEach { meeting in
            let key = meeting.startTime.isoCalStartOfDay
            var d = dic[key]
            if d != nil {
                d?.meetings.append(meeting)
            } else {
                d = MeetingsForDay(date: meeting.startTime, meetings: [meeting])
            }
            dic[key] = d
        }
        return dic.values.sorted { $0.date < $1.date }
    }

    private func limitDisplayMeetings(_ meetings: [Meeting], for date: Date) -> [Meeting] {
        var sameDayMeetings = [Meeting]()
        var otherDayMeetings = [Meeting]()
        meetings.forEach {
            if calendar.isDate($0.startTime, inSameDayAs: date) {
                sameDayMeetings.append($0)
            } else {
                otherDayMeetings.append($0)
            }
        }
        guard sameDayMeetings.count < 8 else {
            return sameDayMeetings
        }
        return sameDayMeetings + otherDayMeetings.prefix(upTo: min(otherDayMeetings.count, 8 - sameDayMeetings.count))
    }

    private var debouncedRequestWorkItem: DispatchWorkItem?
    private var requestsCancellables = Set<AnyCancellable>()

    private func searchMeeting(for date: Date, text: String?) {
        subviewModel.isLoading = true
        subviewModel.searchText = text ?? ""

        requestsCancellables.removeAll()
        debouncePublisher(delay: .milliseconds(300)).sink { [weak self] _ in
            guard let self = self else { return }
            self.requestMeetingsFuture(for: date, text: text)
                .sink { [weak self] meetings in
                    guard let self = self else { return }
                    self.subviewModel.isLoading = false
                    let relevantMeetings = self.limitDisplayMeetings(meetings, for: date)
                    self.subviewModel.meetingsByDay = self.groupMeetingsByDay(relevantMeetings)
                    self.subviewModel.selectedMeeting = self.subviewModel.meetingsByDay.first?.meetings.first
                }.store(in: &self.requestsCancellables)
        }.store(in: &requestsCancellables)
    }

    private func requestMeetingsFuture(for date: Date, text: String?) -> AnyPublisher<[Meeting], Never> {
        Future { [weak self] promise in
            guard let self = self else { return }
            let query = text?.isEmpty == true ? nil : text
            var endDate: Date?
            if query?.isEmpty != false {
                let endOfDisplayedMonthDate = self.calendar.endOfMonth(for: date) ?? date
                let minimumEndDate = self.calendar.date(byAdding: DateComponents(day: 7), to: date) ?? date
                endDate = endOfDisplayedMonthDate > minimumEndDate ? endOfDisplayedMonthDate : minimumEndDate
            }
            self.calendarManager.requestMeetings(for: date, and: endDate, onlyToday: false, query: query) { meetings in
                promise(.success(meetings))
            }
        }.eraseToAnyPublisher()
    }

    // MARK: Key Handlers
    override func formatterHandlesCursorMovement(direction: CursorMovement,
                                                 modifierFlags: NSEvent.ModifierFlags? = nil) -> Bool {
        guard [.up, .down].contains(direction) else { return true }
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
        searchMeeting(for: subviewModel.selectedDate, text: text)
        return true
    }

    // MARK: Private Methods
    override func setupUI() {
        super.setupUI()
        subviewModel.selectedDate = BeamDate.now
        if let todaysNote = todaysNote, let meetings = calendarManager.meetingsForNote[todaysNote.id], !meetings.isEmpty {
            subviewModel.meetingsByDay = [
                MeetingsForDay(date: BeamDate.now.isoCalStartOfDay, meetings: meetings)
            ]
            subviewModel.selectedMeeting = subviewModel.meetingsByDay.first?.meetings.first
        } else {
            searchMeeting(for: subviewModel.selectedDate, text: nil)
        }
        subviewModel.onSelectMeeting = { [weak self] meeting in
            self?.onFinish?(meeting)
        }
        dateObserver = subviewModel.$selectedDate.dropFirst().sink { [weak self] newDate in
            self?.searchMeeting(for: newDate, text: self?.subviewModel.searchText)
        }
        let rootView = MeetingFormatterContainerView(viewModel: subviewModel, calendar: calendar)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        self.addSubview(hostingView)
        hostView = hostingView
        self.layer?.masksToBounds = false
    }
}
