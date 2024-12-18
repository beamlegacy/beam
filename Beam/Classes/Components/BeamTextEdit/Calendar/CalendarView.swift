//
//  CalendarView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 15/10/2021.
//

import SwiftUI
import BeamCore
import Combine

class CalendarGutterViewModel: ObservableObject {
    weak var textRoot: TextRoot?
    @Published var calendarManager: CalendarManager
    var noteId: UUID
    var todaysCalendar: Bool
    var isConnected: Bool {
        !calendarManager.connectedSources.isEmpty
    }

    @Published var meetings: [Meeting] = []
    var scope = Set<AnyCancellable>()

    init(root: TextRoot?, calendarManager: CalendarManager, noteId: UUID, todaysCalendar: Bool) {
        self.textRoot = root
        self.calendarManager = calendarManager
        self.noteId = noteId
        self.todaysCalendar = todaysCalendar
        self.meetings = calendarManager.meetingsForNote[noteId] ?? []

        calendarManager.$meetingsForNote.sink { meetingsForNote in
            self.meetings = meetingsForNote[noteId] ?? []
        }.store(in: &scope)
    }
}

struct CalendarView: View, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    @State var isHoveringConnect = false
    @State var isHoveringNotConnect = false

    @EnvironmentObject var windowInfo: BeamWindowInfo
    @EnvironmentObject var state: BeamState
    @ObservedObject var viewModel: CalendarGutterViewModel

    private var transitionInOutHiddenView: AnyTransition {
        let transitionIn = AnyTransition.move(edge: .leading).animation(BeamAnimation.easingBounce(duration: 0.15))
            .combined(with: .scale(scale: 0.8, anchor: .center).animation(BeamAnimation.easingBounce(duration: 0.15)))
            .combined(with: .scale(scale: 1.2, anchor: .center).animation(BeamAnimation.easingBounce(duration: 0.15)))
            .combined(with: .opacity.animation(.easeInOut(duration: 0.15)))

        let transitionOut = AnyTransition.move(edge: .leading).animation(BeamAnimation.easingBounce(duration: 0.15))
            .combined(with: .scale(scale: 1.2, anchor: .center).animation(BeamAnimation.easingBounce(duration: 0.15)))
            .combined(with: .scale(scale: 0.8, anchor: .center).animation(BeamAnimation.easingBounce(duration: 0.15)))
            .combined(with: .opacity.animation(.easeInOut(duration: 0.15)))

        return AnyTransition.asymmetric(insertion: transitionIn, removal: transitionOut)
    }

    static let bottomPadding: CGFloat = 4
    static let itemSpacing: CGFloat = 8

    var body: some View {
        if viewModel.isConnected {
            VStack(alignment: .leading) {
                if isHoveringConnect && !windowInfo.windowIsResizing {
                    VStack(alignment: .leading, spacing: CalendarView.itemSpacing) {
                        ForEach(viewModel.meetings) { meeting in
                            CalendarItemView(allDayEvent: meeting.allDayEvent, time: meeting.startTime,
                                            meetingLink: meeting.meetingLink, title: meeting.name, onClick: {
                                prompt(meeting)
                            }).padding(.bottom, CalendarView.bottomPadding)
                        }
                    }.transition(AnyTransition.asymmetric(
                        insertion: .move(edge: .leading).animation(BeamAnimation.easingBounce(duration: 0.15).delay(0.15))
                            .combined(with: .opacity.animation(.easeInOut(duration: 0.15).delay(0.15))),
                        removal: .move(edge: .leading).animation(BeamAnimation.easingBounce(duration: 0.15))
                            .combined(with: .opacity.animation(.easeInOut(duration: 0.15)))
                    ))
                        .padding(6)
                        .background(background())
                } else {
                    VStack(alignment: .leading, spacing: CalendarView.itemSpacing) {
                        ForEach(viewModel.meetings) { meeting in
                            CalendarItemHiddenView(meetingDuration: meeting.duration, isCompact: shouldUseCompactMode)
                                .frame(height: CalendarItemView.itemSize.height)
                                .padding(.bottom, CalendarView.bottomPadding)
                        }
                    }.transition(transitionInOutHiddenView)
                }
            }.onHover { isHovering in
                guard !state.shouldDisableLeadingGutterHover else { return }
                withAnimation {
                    isHoveringConnect = isHovering
                    state.isHoverLeadingGutter = isHovering
                }
            }
        } else if viewModel.todaysCalendar && viewModel.calendarManager.showedNotConnectedView < 3 && !viewModel.isConnected {
            isNotConnectedView
                .padding(.leading, 16)
                .foregroundColor(isHoveringNotConnect ? BeamColor.Niobium.swiftUI : BeamColor.Generic.placeholder.swiftUI)
                .animation(.easeInOut(duration: 0.3))
                .onHover { isHoveringNotConnect = $0 }
                .onTapGesture {
                    openCalendarsPreferences()
                }
                .cursorOverride(.pointingHand)
        }
    }

    @ViewBuilder func background(if condition: Bool = true) -> some View {
        if condition {
            ZStack {
                VisualEffectView(material: .headerView)
                BeamColor.Generic.background.swiftUI.opacity(0.3)
            }.cornerRadius(4)
                .padding(.leading, 4)
        }
    }

    private var shouldUseCompactMode: Bool {
        if let width = viewModel.textRoot?.editor?.frame.width, width < 500 {
            return true
        } else {
            return false
        }
    }

    private var isNotConnectedView: some View {
        HStack(spacing: 5) {
            VStack {
                Image("editor-calendar")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                Spacer()
            }.frame(width: 21)
            if isHoveringNotConnect {
                VStack(alignment: .leading, spacing: 4.5) {
                    Text("Connect your Calendar")
                        .font(BeamFont.medium(size: 12).swiftUI)
                    Text("Write a meeting note or join a video call")
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .font(BeamFont.regular(size: 11).swiftUI)
                    Spacer()
                }
            }
        }
        .padding(6)
        .background(background(if: isHoveringNotConnect))
    }

    private func openCalendarsPreferences() {
        (NSApp.delegate as? AppDelegate)?.openPreferencesWindow(to: .calendars)
    }

    private func prompt(_ meeting: Meeting) {
        let state = AppDelegate.main.window?.state
        let model = MeetingModalView.ViewModel(meetingName: meeting.name, startTime: meeting.startTime,
                                               attendees: meeting.attendees,
                                               onFinish: { meeting in
            if let meeting = meeting, let todaysNote = state?.data.todaysNote {
                if meeting.startTime != BeamDate.now {
                    let meetingDateNote = BeamNote.fetch(journalDate: meeting.startTime)
                    self.addMeeting(meeting, to: meetingDateNote ?? todaysNote)
                } else {
                    self.addMeeting(meeting, to: todaysNote)
                }
            }
            state?.overlayViewModel.modalView = nil
        })
        state?.overlayViewModel.modalView = AnyView(MeetingModalView(viewModel: model))
    }

    private func addMeeting(_ meeting: Meeting, to note: BeamNote) {
        var text = BeamText(text: "")
        var meetingAttributes: [BeamText.Attribute] = []
        if meeting.linkCards {
            guard let meetingNote = try? BeamNote.fetchOrCreate(self, title: meeting.name) else { return }
            meetingAttributes = [.internalLink(meetingNote.id)]
        }
        if !meeting.name.isEmpty {
            text.insert(meeting.name, at: 0, withAttributes: meetingAttributes)
        }

        if !meeting.attendees.isEmpty {
            let prefix = "Meeting with "
            var position = prefix.count
            text.insert(prefix, at: 0, withAttributes: [])
            meeting.attendees.enumerated().forEach { index, attendee in
                guard !attendee.name.isEmpty else { return }
                let name = attendee.name
                guard let attendeeNote = try? BeamNote.fetchOrCreate(self, title: name) else { return }
                text.insert(name, at: position, withAttributes: [.internalLink(attendeeNote.id)])
                position += name.count
                if index < meeting.attendees.count - 1 {
                    let separator = ", "
                    text.insert(separator, at: position, withAttributes: [])
                    position += separator.count
                }
            }
            if !meeting.name.isEmpty {
                text.insert(" for ", at: position, withAttributes: [])
            }
        }
        if let element = note.children.last, element.text.isEmpty {
            element.text = text
        } else {
            note.insert(BeamElement(text), after: note.children.last)
        }

        guard let lastElement = note.children.last, let root = viewModel.textRoot else { return }
        note.cmdManager.focus(lastElement, in: root)
    }
}

struct CalendarItemHiddenView: View {
    var meetingDuration: DateComponents?
    var isCompact: Bool

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(BeamColor.AlphaGray.alpha(0.40).swiftUI)
                .frame(width: isCompact ? 14 : getWidthForDuration(), height: 2)
                .animation(.easeInOut, value: isCompact)
        }.padding(.leading, 14)
    }

    private func getWidthForDuration() -> CGFloat {
        let maxWidth: CGFloat = 26
        let minWidth: CGFloat = 14
        let logMaxWidth = log(maxWidth)
        let logMinWidth = log(minWidth)
        let hours = meetingDuration?.hour ?? 0
        let minutes = meetingDuration?.minute ?? 0
        let totalMinutes: CGFloat = CGFloat((hours * 60 + minutes))
        let scale = (logMaxWidth - logMinWidth) / (maxWidth - minWidth)

        let value = (((log(totalMinutes) - logMinWidth) / scale) + minWidth)

        return CGFloat(max(minWidth, min(value, maxWidth)))
    }
}

struct CalendarItemView: View {
    static let itemSize = CGSize(width: 16, height: 16)
    var allDayEvent: Bool
    var time: Date
    var meetingLink: String?
    var title: String
    var onClick: (() -> Void)

    @State var isHoveringItem = false
    @State var isHoveringMeetingBtn = false

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                if !allDayEvent {
                    Text(time.formatHourMin)
                        .font(BeamFont.regular(size: 11).swiftUI)
                        .foregroundColor(isHoveringItem ? BeamColor.Niobium.swiftUI : BeamColor.AlphaGray.swiftUI)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(width: 24, alignment: .trailing)
                }
                if let meetingLink = meetingLink, let url = URL(string: meetingLink) {
                    Button {
                        do {
                            let (state, data) = (AppDelegate.main.window?.state, AppDelegate.main.window?.data)
                            try state?.videoCallsManager.start(with: .init(url: url), faviconProvider: data?.faviconProvider)
                        } catch VideoCallsManager.Error.existingSession {
                            // no-op, existing window already foreground
                        } catch {
                            UserAlert.showError(error: error)
                        }
                    } label: {
                        Image("editor-calendar_video")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: CalendarItemView.itemSize.width, height: CalendarItemView.itemSize.height)
                            .foregroundColor(isHoveringMeetingBtn ? BeamColor.Bluetiful.swiftUI : isHoveringItem ? BeamColor.Niobium.swiftUI : BeamColor.AlphaGray.swiftUI)
                    }.buttonStyle(PlainButtonStyle())
                        .frame(width: CalendarItemView.itemSize.width, height: CalendarItemView.itemSize.height, alignment: .leading)
                        .padding(.bottom, 1)
                        .onHover { isHoveringMeetingBtn = $0 }
                }
                Text(title)
                    .font(BeamFont.regular(size: 12).swiftUI)
                    .foregroundColor(isHoveringItem ? BeamColor.Niobium.swiftUI : BeamColor.LightStoneGray.swiftUI)
                    .frame(alignment: .leading)
                if isHoveringItem {
                    Image("editor-calendar_arrow")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundColor(BeamColor.Niobium.swiftUI)
                        .transition(AnyTransition.asymmetric(
                                insertion: .opacity.animation(.easeInOut(duration: 0.15).delay(0.10)),
                                removal: .opacity.animation(.easeInOut(duration: 0.15))
                            ))
                }
                else {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 10, height: 10)
                }
            }
        }.frame(height: CalendarItemView.itemSize.height)
        .padding(.leading, 16)
        .onHover { isHovering in
            isHoveringItem = isHovering
        }
        .onTapGesture {
                onClick()
        }
        .blendModeLightMultiplyDarkScreen()
    }
}
