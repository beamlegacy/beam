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
                        CalendarIemView(time: meeting.startTime, title: meeting.name, onClick: {
                            prompt(meeting)
                        })
                    } else {
                        CalendarItemHiddenView(itemStr: meeting.name)
                    }
                }
            }
                .onHover { isHoveringConnect = $0 }
                .animation(.easeInOut(duration: 0.3))
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
                Image("status-connection_issue")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(BeamColor.Shiraz.swiftUI)
                Spacer()
            }.frame(width: 21)
            if isHoveringNotConnect {
                VStack {
                    HStack {
                        Text("Permissions Access")
                            .font(BeamFont.medium(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Shiraz.swiftUI)
                        Image("editor-calendar_arrow")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 10, height: 10)
                            .foregroundColor(BeamColor.Shiraz.swiftUI)
                    }
                    Text("You need to give Beam access to your Google Calendar & Contacts from Beam’s Account Preferences")
                        .lineLimit(8)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .font(BeamFont.medium(size: 12).swiftUI)
                        .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                        .frame(width: 130)
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
        guard let documentManager = AppDelegate.main.window?.state.data.documentManager else { return }
        var text = BeamText(text: "")
        var meetingAttributes: [BeamText.Attribute] = []
        if meeting.linkCards {
            let meetingNote = BeamNote.fetchOrCreate(documentManager, title: meeting.name)
            meetingAttributes = [.internalLink(meetingNote.id)]
        }
        text.insert(meeting.name, at: 0, withAttributes: meetingAttributes)

        if !meeting.attendees.isEmpty {
            let prefix = "Meeting with "
            var position = prefix.count
            text.insert(prefix, at: 0, withAttributes: [])
            meeting.attendees.enumerated().forEach { index, attendee in
                let name = attendee.name
                let attendeeNote = BeamNote.fetchOrCreate(documentManager, title: name)
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
        let e = BeamElement(text)
        note.insert(e, after: note.children.last)
    }
}

struct CalendarItemHiddenView: View {
    var itemStr: String

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(BeamColor.AlphaGray.swiftUI)
                .frame(width: itemStr.widthOfString(usingFont: BeamFont.regular(size: 12).nsFont), height: 2)
        }.padding(.bottom, 20)
            .padding(.leading, 14)
    }
}

struct CalendarIemView: View {
    var time: Date
    var title: String
    var onClick: (() -> Void)

    @State var isHovering = false

    var body: some View {
        VStack {
            HStack {
                Text(time.formatHourMin)
                    .font(BeamFont.regular(size: 10).swiftUI)
                    .foregroundColor(isHovering ? BeamColor.Niobium.swiftUI : BeamColor.AlphaGray.swiftUI)
                Text(title)
                    .font(isHovering ? BeamFont.bold(size: 12).swiftUI : BeamFont.regular(size: 12).swiftUI)
                    .foregroundColor(isHovering ? BeamColor.Niobium.swiftUI : BeamColor.LightStoneGray.swiftUI)
                if isHovering {
                    Image("editor-calendar_arrow")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundColor(BeamColor.Beam.swiftUI)
                }
            }.frame(height: 15)
        }.padding(.bottom, 12)
        .padding(.leading, 14)
            .onHover {
                isHovering = $0
            }.onTapGesture {
                onClick()
            }
    }
}
