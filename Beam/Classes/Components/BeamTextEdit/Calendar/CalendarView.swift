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
    @Published var calendarManager: CalendarManager
    var noteId: UUID
    var isConnected: Bool {
        calendarManager.isConnected(calendarService: .googleCalendar)
    }
    @Published var meetings: [Meeting] = []
    var scope = Set<AnyCancellable>()

    init(calendarManager: CalendarManager, noteId: UUID) {
        self.calendarManager = calendarManager
        self.noteId = noteId
        self.meetings = calendarManager.meetingsForNote[noteId] ?? []

        calendarManager.$meetingsForNote.sink { meetingsForNote in
            self.meetings = meetingsForNote[noteId] ?? []
        }.store(in: &scope)
    }
}

struct CalendarView: View {
    @State var isHoveringConnect = false
    @State var isHoveringNotConnect = false
    @ObservedObject var viewModel: CalendarGutterViewModel

    var body: some View {
        if viewModel.isConnected {
            VStack(alignment: .leading) {
                ForEach(viewModel.meetings) { meeting in
                    if isHoveringConnect {
                        CalendarIemView(allDayEvent: meeting.allDayEvent, time: meeting.startTime,
                                        meetingLink: meeting.meetingLink, title: meeting.name, onClick: {
                            prompt(meeting)
                        }).transition(AnyTransition.asymmetric(
                                insertion: AnyTransition.move(edge: .leading).animation(BeamAnimation.spring(stiffness: 400, damping: 20).delay(0.10)) .combined(with: .opacity.animation(.easeInOut(duration: 0.15).delay(0.10))),
                                removal: AnyTransition.move(edge: .leading).animation(BeamAnimation.spring(stiffness: 400, damping: 35)).combined(with: .opacity.animation(.easeInOut(duration: 0.15)))
                            ))
                    } else {
                        CalendarItemHiddenView(meetingDuration: meeting.duration)
                            .frame(minHeight: 16, maxHeight: 16)
                            .padding(.top, 4)
                            .transition(AnyTransition.asymmetric(
                                insertion: AnyTransition.scale(scale: 1.5, anchor: .leading).animation(BeamAnimation.spring(stiffness: 400, damping: 25).delay(0.15)).combined(with: .opacity.animation(.easeInOut(duration: 0.15).delay(0.15))),
                                removal: AnyTransition.scale(scale: 0.1, anchor: .leading).animation(BeamAnimation.spring(stiffness: 400, damping: 25)).combined(with: .opacity.animation(.easeInOut(duration: 0.15)))))
                    }
                }
            }.onHover { isHovering in
                withAnimation {
                    isHoveringConnect = isHovering
                }
            }
        } else {
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
                    .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                Spacer()
            }.frame(width: 21)
            if isHoveringNotConnect {
                VStack(alignment: .leading, spacing: 4.5) {
                    Text("Connect your Calendar")
                        .font(BeamFont.medium(size: 12).swiftUI)
                        .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                    Text("Write a meeting note or join a video call")
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .font(BeamFont.regular(size: 11).swiftUI)
                        .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                    Spacer()
                }
            }
        }.frame(width: 161, alignment: .leading)
    }

    private func prompt(_ meeting: Meeting) {
        let state = AppDelegate.main.window?.state
        let model = MeetingModalView.ViewModel(meetingName: meeting.name, startTime: meeting.startTime,
                                               attendees: meeting.attendees,
                                               onFinish: { meeting in
            if let meeting = meeting, let note = state?.data.todaysNote {
                self.addMeeting(meeting, to: note)
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
        text.insert(meeting.name, at: 0, withAttributes: meetingAttributes)

        if !meeting.attendees.isEmpty {
            let prefix = "Meeting with "
            var position = prefix.count
            text.insert(prefix, at: 0, withAttributes: [])
            meeting.attendees.enumerated().forEach { index, attendee in
                let name = attendee.name
                let attendeeNote = BeamNote.fetchOrCreate(title: name)
                text.insert(name, at: position, withAttributes: [.internalLink(attendeeNote.id)])
                position += name.count
                if index < meeting.attendees.count - 1 {
                    let separator = ", "
                    text.insert(separator, at: position, withAttributes: [])
                    position += separator.count
                }
            }
            text.insert(" for ", at: position, withAttributes: [])
        }
        if let lastBeamElementText = note.children.last?.text, lastBeamElementText.isEmpty {
            note.children.last?.text = text
        } else {
            note.insert(BeamElement(text), after: note.children.last)
        }
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
        let maxWidth: CGFloat = 70
        let minWidth: CGFloat = 8
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
                    .font(isHoveringItem ? BeamFont.medium(size: 12).swiftUI : BeamFont.regular(size: 12).swiftUI)
                    .foregroundColor(isHoveringItem ? BeamColor.Niobium.swiftUI : BeamColor.LightStoneGray.swiftUI)
                if isHoveringItem {
                    Image("editor-calendar_arrow")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundColor(BeamColor.Niobium.swiftUI)
                }
            }
        }.frame(minHeight: 16, maxHeight: 16)
        .padding(.top, 4)
        .padding(.leading, 14)
            .onHover {
                isHoveringItem = $0
            }.onTapGesture {
                onClick()
            }
    }
}
