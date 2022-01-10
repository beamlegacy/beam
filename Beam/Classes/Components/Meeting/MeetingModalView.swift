//
//  MeetingModalView.swift
//  Beam
//
//  Created by Remi Santos on 28/09/2021.
//

import SwiftUI
import BeamCore

struct Meeting: Identifiable, Equatable {

    var id: UUID = UUID()
    var name: String
    var startTime: Date
    var endTime: Date?
    var allDayEvent: Bool = false
    var attendees: [Attendee]
    var htmlLink: String?
    var meetingLink: String?
    var linkCards: Bool = true
    var duration: DateComponents? {
        guard let endTime = endTime else { return nil }
        return Calendar.current.dateComponents([.hour, .minute], from: startTime, to: endTime)
    }

    static func == (lhs: Meeting, rhs: Meeting) -> Bool {
        return lhs.name == rhs.name && lhs.startTime == rhs.startTime && lhs.attendees == rhs.attendees
    }

    class Attendee: Identifiable, Equatable {
        var id: UUID = UUID()

        var email: String
        var name: String

        init(email: String, name: String) {
            self.email = email
            self.name = name

            if let atChar = self.email.range(of: "@"), self.name.isEmpty {
                self.name = String(self.email.prefix(upTo: atChar.lowerBound))
                self.name = self.name.prefix(1).capitalized + self.name.dropFirst()
            }
        }

        static func == (lhs: Attendee, rhs: Attendee) -> Bool {
            return lhs.name == rhs.name && lhs.email == rhs.email
        }
    }
}

struct MeetingModalView: View {
    @ObservedObject var viewModel: ViewModel

    private var isContentScrollable: Bool {
        viewModel.attendees.count > 5
    }

    @State private var hoveredCloseButtonIndex: Int?

    // macOS >= 12 has @FocusState that works with .focused(_, equals:). Trying to mimic the pattern here.
    @State private var focusedField: FocusableField?
    private enum FocusableField: Hashable, Equatable {
        case meetingName
        case attendeeName(_ attendeeId: UUID)
        case attendeeEmail(_ attendeeId: UUID)
    }

    var body: some View {
        FormatterViewBackground {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Meeting")
                                .font(BeamFont.regular(size: 12).swiftUI)
                                .foregroundColor(BeamColor.AlphaGray.swiftUI)
                                .padding(.bottom, BeamSpacing._120)

                            HStack {
                                BoxedTextFieldView(title: "Meeting Title (Optional)", text: $viewModel.meetingName, isEditing: Binding<Bool>(
                                    get: { focusedField == .meetingName },
                                    set: {
                                        if $0 {
                                            focusedField = .meetingName
                                        } else if focusedField == .meetingName {
                                            focusedField = nil
                                        }
                                    }), foregroundColor: BeamColor.Beam)
                                Icon(name: "tool-close",
                                     color: hoveredCloseButtonIndex == -1 ? BeamColor.Corduroy.swiftUI : BeamColor.AlphaGray.swiftUI)
                                    .onTapGesture {
                                        viewModel.meetingName = ""
                                    }
                                    .onHover { h in
                                        hoveredCloseButtonIndex = h ? -1 : nil
                                    }
                            }

                            Text("Attendees")
                                .font(BeamFont.regular(size: 12).swiftUI)
                                .foregroundColor(BeamColor.AlphaGray.swiftUI)
                                .padding(.top, 30)
                                .padding(.bottom, BeamSpacing._120)
                            VStack(spacing: BeamSpacing._80) {
                                ForEach(Array(viewModel.attendees.enumerated()), id: \.1.id) { index, attendee in
                                    HStack(spacing: BeamSpacing._80) {
                                        BoxedTextFieldView(title: "Email Address", text: Binding<String>(
                                            get: { attendee.email },
                                            set: {
                                                if let noteId = ContactsManager.shared.note(for: $0),
                                                   let name = BeamNote.fetch(id: noteId, includeDeleted: false)?.title {
                                                        viewModel.attendees[index].name = name
                                                }
                                                viewModel.attendees[index].email = $0
                                            }),
                                                           isEditing: Binding<Bool>(
                                                            get: { focusedField == .attendeeEmail(attendee.id) },
                                                            set: {
                                                                if $0 {
                                                                    focusedField = .attendeeEmail(attendee.id)
                                                                } else if focusedField == .attendeeEmail(attendee.id) {
                                                                    focusedField = nil
                                                                }
                                                            }),
                                                           onCommit: { viewModel.addMeeting() },
                                                           onBackspace: { if attendee.email.isEmpty { viewModel.removeAttendee(attendee) } },
                                                           onEscape: { viewModel.cancel() })
                                        BoxedTextFieldView(title: "Name", text: Binding<String>(
                                            get: {
                                                // Return note title (name) if email already in ContactDB
                                                guard let noteId = ContactsManager.shared.note(for: attendee.email),
                                                      let name = BeamNote.fetch(id: noteId, includeDeleted: false)?.title, viewModel.attendees.count > index else { return attendee.name }
                                                viewModel.attendees[index].name = name
                                                return name
                                            },
                                            set: {
                                                // Search for existing Note with contact
                                                viewModel.attendees[index].name = ContactsManager.shared.search(for: $0)
                                            }),
                                                           isEditing: Binding<Bool>(
                                                            get: { focusedField == .attendeeName(attendee.id) },
                                                            set: {
                                                                if $0 {
                                                                    focusedField = .attendeeName(attendee.id)
                                                                } else if focusedField == .attendeeName(attendee.id) {
                                                                    focusedField = nil
                                                                }
                                                            }),
                                                           foregroundColor: BeamColor.Beam,
                                                           onCommit: { viewModel.addMeeting() },
                                                           onEscape: { viewModel.cancel() },
                                                           onTab: {
                                            if index == viewModel.attendees.count - 1 {
                                                viewModel.createNewAttendee()
                                                focusLastAttendee(scrollViewProxy: proxy)
                                                return true
                                            }
                                            return false
                                        })
                                        Icon(name: "tool-close",
                                             color: hoveredCloseButtonIndex == index ? BeamColor.Corduroy.swiftUI : BeamColor.AlphaGray.swiftUI)
                                            .onTapGesture {
                                                viewModel.removeAttendee(attendee)
                                            }
                                            .onHover { h in
                                                hoveredCloseButtonIndex = h ? index : nil
                                            }
                                    }
                                    .id(attendee.id)
                                }
                                if viewModel.canAddAttendee {
                                    MeetingModalAddAttendeeRow()
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            viewModel.createNewAttendee()
                                            focusLastAttendee(scrollViewProxy: proxy)
                                        }.id("add-attendee")
                                }
                            }
                        }
                        .padding([.horizontal, .top], BeamSpacing._400)
                        .padding(.bottom, BeamSpacing._200)
                    }
                }

                HStack(spacing: BeamSpacing._200) {
                    HStack(spacing: BeamSpacing._60) {
                        CheckboxView(checked: $viewModel.linkCards)
                        Text("Link Notes")
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    }.onTapGesture {
                        viewModel.linkCards.toggle()
                    }
                    Spacer()
                    ActionableButton(text: "Cancel", defaultState: .normal, variant: .secondary, minWidth: 120) {
                        viewModel.cancel()
                    }
                    ActionableButton(text: "Add", defaultState: viewModel.meetingName.isEmpty && viewModel.attendees.isEmpty ? .disabled : .normal, variant: .primaryPurple, minWidth: 120) {
                        viewModel.addMeeting()
                    }
                }
                .padding(.horizontal, BeamSpacing._400)
                .padding(.vertical, isContentScrollable ? 30 : BeamSpacing._400)
                .border(BeamColor.Nero.swiftUI.opacity(isContentScrollable ? 1 : 0))
            }
            .background(KeyEventHandlingView(handledKeyCodes: [.enter, .escape], firstResponder: true, onKeyDown: { v in
                if v.keyCode == KeyCode.enter.rawValue {
                    viewModel.addMeeting()
                } else {
                    viewModel.cancel()
                }
            }))
        }
        .frame(width: 728)
        .frame(minHeight: 300, maxHeight: 500)
        .fixedSize(horizontal: false, vertical: true)
    }

    func focusLastAttendee(scrollViewProxy: ScrollViewProxy) {
        guard let last = viewModel.attendees.last else { return }
        focusedField = .attendeeEmail(last.id)
        DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(100))) {
            scrollViewProxy.scrollTo("add-attendee")
        }
    }
}

private struct MeetingModalAddAttendeeRow: View {
    @State private var isHovering = false
    private var foregroundColor: Color {
        isHovering ? BeamColor.Corduroy.swiftUI : BeamColor.LightStoneGray.swiftUI
    }
    var body: some View {
        HStack(spacing: BeamSpacing._80) {
            HStack(spacing: 0) {
                Text("Add Attendee")
                    .font(BeamFont.regular(size: 12).swiftUI)
                    .foregroundColor(foregroundColor)
                    .padding(BeamSpacing._80)
                Spacer()
            }
            .border(BoxedTextFieldView.borderColor.swiftUI, width: 1.5)
            .cornerRadius(3.0)
            Icon(name: "tool-new", color: isHovering ? BeamColor.Corduroy.swiftUI : BeamColor.AlphaGray.swiftUI)
        }
        .onHover { isHovering = $0 }
    }
}

extension MeetingModalView {

    class ViewModel: ObservableObject {
        @Published fileprivate var meetingName: String
        @Published fileprivate var startTime: Date
        @Published fileprivate var attendees: [Meeting.Attendee]
        @Published fileprivate var additionalAttendee = Meeting.Attendee(email: "", name: "")
        @Published fileprivate var linkCards: Bool = true

        private var onFinish: ((Meeting?) -> Void)?

        var canAddAttendee: Bool {
            true
        }

        init(meetingName: String, startTime: Date, attendees: [Meeting.Attendee], onFinish: ((Meeting?) -> Void)? = nil) {
            self.meetingName = meetingName
            self.startTime = startTime
            self.attendees = attendees
            self.onFinish = onFinish
        }

        func removeAttendee(_ attendee: Meeting.Attendee) {
            self.attendees.removeAll { $0.id == attendee.id }
        }

        func createNewAttendee() {
            self.attendees.append(.init(email: "", name: ""))
        }

        func addMeeting() {
            let meeting = Meeting(name: meetingName, startTime: startTime, attendees: attendees, linkCards: linkCards)
            onFinish?(meeting)
        }

        func cancel() {
            onFinish?(nil)
        }
    }
}
struct MeetingModalView_Previews: PreviewProvider {
    static let model = MeetingModalView.ViewModel(meetingName: "Some Meeting Name", startTime: BeamDate.now, attendees: [
        Meeting.Attendee(email: "stef@beamapp.co", name: "Stef"),
        Meeting.Attendee(email: "luis@beamapp.co", name: "Luis"),
        Meeting.Attendee(email: "remi@beamapp.co", name: "Remi")
    ])
    static var previews: some View {
        MeetingModalView(viewModel: model)
            .frame(width: 800, height: 500)
    }
}
