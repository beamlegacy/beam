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
        calendarManager.connectedSources.count > 0
    }
    @UserDefault(key: "showedNotConnectedViewKey", defaultValue: 0)
    var showedNotConnectedView: Int

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

struct CalendarView: View {
    @State var isHoveringConnect = false
    @State var isHoveringNotConnect = false

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

    var body: some View {
        if viewModel.isConnected {
            VStack(alignment: .leading) {
                if isHoveringConnect {
                    VStack(alignment: .leading) {
                        ForEach(viewModel.meetings) { meeting in
                            CalendarIemView(allDayEvent: meeting.allDayEvent, time: meeting.startTime,
                                            meetingLink: meeting.meetingLink, title: meeting.name, onClick: {
                                prompt(meeting)
                            }).padding(.bottom, 4)
                        }
                    }.transition(AnyTransition.asymmetric(
                        insertion: .move(edge: .leading).animation(BeamAnimation.easingBounce(duration: 0.15).delay(0.15))
                            .combined(with: .opacity.animation(.easeInOut(duration: 0.15).delay(0.15))),
                            removal: .move(edge: .leading).animation(BeamAnimation.easingBounce(duration: 0.15))
                            .combined(with: .opacity.animation(.easeInOut(duration: 0.15)))
                        ))
                } else {
                    VStack(alignment: .leading) {
                        ForEach(viewModel.meetings) { meeting in
                            CalendarItemHiddenView(meetingDuration: meeting.duration)
                                .frame(minHeight: 16, maxHeight: 16)
                                .padding(.bottom, 4)
                        }
                    }.transition(transitionInOutHiddenView)
                }
            }.onHover { isHovering in
                guard !state.shouldDisableLeadingGutterHover else { return }
                withAnimation {
                    isHoveringConnect = isHovering
                }
            }
        } else if viewModel.todaysCalendar && viewModel.showedNotConnectedView <= 3 && !viewModel.isConnected {
            isNotConnectedView
                .padding(.leading, 14)
                .onHover { isHoveringNotConnect = $0 }
                .animation(.easeInOut(duration: 0.3))
                .onTapGesture {
                    AppDelegate.main.openPreferencesWindow(to: .accounts)
                }
        }
    }

    private var isNotConnectedView: some View {
        HStack(spacing: 5) {
            VStack {
                Image("editor-calendar")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
                Spacer()
            }.frame(width: 21)
            if isHoveringNotConnect {
                VStack(alignment: .leading, spacing: 4.5) {
                    Text("Connect your Calendar")
                        .font(BeamFont.medium(size: 12).swiftUI)
                        .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
                    Text("Write a meeting note or join a video call")
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .font(BeamFont.regular(size: 11).swiftUI)
                        .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
                    Spacer()
                }
            }
        }.frame(width: 161, alignment: .leading)
            .onAppear {
                viewModel.showedNotConnectedView += 1
            }
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
            let meetingNote = BeamNote.fetchOrCreate(title: meeting.name)
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
                let name = attendee.name
                let attendeeNote = BeamNote.fetchOrCreate(title: name)
                saveContacts(for: attendee, and: attendeeNote)
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

    private func saveContacts(for attendee: Meeting.Attendee, and attendeeNote: BeamNote) {
        guard let contactRecord = ContactsManager.shared.save(email: attendee.email, to: attendeeNote.id, networkCompletion: { _ in }) else { return }
        attendeeNote.contactId = contactRecord.uuid
        attendeeNote.save()
    }
}

struct CalendarItemHiddenView: View {
    var meetingDuration: DateComponents?

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(BeamColor.AlphaGray.alpha(0.40).swiftUI)
                .frame(width: getWidthForDuration(), height: 2)
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

struct CalendarIemView: View {
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
                }
                if let meetingLink = meetingLink {
                    Button {
                        _ = AppDelegate.main.window?.state.addNewTab(origin: nil, setCurrent: true, note: nil, element: nil, url: URL(string: meetingLink), webView: nil)
                    } label: {
                        Image("editor-calendar_video")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(isHoveringMeetingBtn ? BeamColor.Bluetiful.swiftUI : isHoveringItem ? BeamColor.Niobium.swiftUI : BeamColor.AlphaGray.swiftUI)
                    }.buttonStyle(PlainButtonStyle())
                        .frame(width: 16, height: 16)
                        .padding(.bottom, 1)
                        .onHover { isHoveringMeetingBtn = $0 }
                }
                Text(title)
                    .font(BeamFont.regular(size: 12).swiftUI)
                    .foregroundColor(isHoveringItem ? BeamColor.Niobium.swiftUI : BeamColor.LightStoneGray.swiftUI)
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
            }
        }.frame(minHeight: 16, maxHeight: 16)
        .padding(.leading, 14)
        .onHover { isHovering in
            isHoveringItem = isHovering
        }
        .onTapGesture {
                onClick()
        }
    }
}
