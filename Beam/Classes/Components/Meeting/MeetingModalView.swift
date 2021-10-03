//
//  MeetingModalView.swift
//  Beam
//
//  Created by Remi Santos on 28/09/2021.
//

import SwiftUI

struct Meeting {
    var name: String
    var attendees: [Attendee]
    var linkCards: Bool

    class Attendee: Identifiable {
        var id: UUID = UUID()

        var email: String
        var name: String

        init(email: String, name: String) {
            self.email = email
            self.name = name
        }
    }
}

struct MeetingModalView: View {
    @ObservedObject var viewModel: ViewModel

    private var isContentScrollable: Bool {
        viewModel.attendees.count > 5
    }

    var body: some View {
        FormatterViewBackground {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Meeting")
                            .font(BeamFont.medium(size: 12).swiftUI)
                            .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                            .padding(.bottom, BeamSpacing._120)

                        HStack {
                            BoxedTextFieldView(title: "Meeting Title", text: $viewModel.meetingName)
                            Icon(name: "tabs-close", color: BeamColor.AlphaGray.swiftUI)
                                .onTapGesture {
                                    viewModel.meetingName = ""
                                }
                        }

                        Text("Attendees")
                            .font(BeamFont.medium(size: 12).swiftUI)
                            .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                            .padding(.top, 30)
                            .padding(.bottom, BeamSpacing._120)
                        VStack(spacing: BeamSpacing._80) {
                            ForEach(Array(viewModel.attendees.enumerated()), id: \.1.id) { index, attendee in
                                HStack(spacing: BeamSpacing._80) {
                                    BoxedTextFieldView(title: "Email Address", text: Binding<String>(
                                                    get: { attendee.email },
                                                    set: { viewModel.attendees[index].email = $0 }))
                                    BoxedTextFieldView(title: "Name", text: Binding<String>(
                                                    get: { attendee.name },
                                                    set: { viewModel.attendees[index].name = $0 }), foregroundColor: BeamColor.Beam)
                                    Icon(name: "tabs-close", color: BeamColor.AlphaGray.swiftUI)
                                        .onTapGesture {
                                            viewModel.removeAttendee(attendee)
                                        }
                                }
                            }
                            if viewModel.canAddAttendee {
                                HStack(spacing: BeamSpacing._80) {
                                    BoxedTextFieldView(title: "Email Address", text: $viewModel.additionalAttendee.email, onCommit: {
                                        viewModel.onCommitNewAttendee()
                                    })
                                    BoxedTextFieldView(title: "Name", text: $viewModel.additionalAttendee.name, onCommit: {
                                        viewModel.onCommitNewAttendee()
                                    })
                                    Icon(name: "tabs-close").opacity(0)
                                }
                            }
                        }
                    }
                    .padding([.horizontal, .top], BeamSpacing._400)
                    .padding(.bottom, BeamSpacing._200)
                }

                HStack {
                    HStack(spacing: BeamSpacing._60) {
                        CheckboxView(checked: $viewModel.linkCards)
                        Text("Link Cards")
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    }.onTapGesture {
                        viewModel.linkCards.toggle()
                    }
                    Spacer()
                    ActionableButton(text: "Cancel", defaultState: .normal, variant: .secondary) {
                        viewModel.cancel()
                    }
                    ActionableButton(text: "Add Meeting", defaultState: .normal, variant: .primaryPurple) {
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
        .frame(width: 600)
        .frame(minHeight: 300, maxHeight: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension MeetingModalView {

    class ViewModel: ObservableObject {
        @Published fileprivate var attendees: [Meeting.Attendee]
        @Published fileprivate var meetingName: String
        @Published fileprivate var additionalAttendee = Meeting.Attendee(email: "", name: "")
        @Published fileprivate var linkCards: Bool = true

        private var onFinish: ((Meeting?) -> Void)?

        var canAddAttendee: Bool {
            true
        }

        init(meetingName: String, attendees: [Meeting.Attendee], onFinish: ((Meeting?) -> Void)? = nil) {
            self.meetingName = meetingName
            self.attendees = attendees
            self.onFinish = onFinish
        }

        func removeAttendee(_ attendee: Meeting.Attendee) {
            self.attendees.removeAll { $0.id == attendee.id }
        }

        func onCommitNewAttendee() {
            guard !additionalAttendee.email.isEmpty && !additionalAttendee.name.isEmpty else { return }

            self.attendees.append(additionalAttendee)
            self.additionalAttendee = .init(email: "", name: "")
        }

        func addMeeting() {
            guard !meetingName.isEmpty else { return }
            let meeting = Meeting(name: meetingName, attendees: attendees, linkCards: linkCards)
            onFinish?(meeting)
        }

        func cancel() {
            onFinish?(nil)
        }
    }
}
struct MeetingModalView_Previews: PreviewProvider {
    static let model = MeetingModalView.ViewModel(meetingName: "Some Meeting Name", attendees: [
        Meeting.Attendee(email: "stef@beamapp.co", name: "Stef"),
        Meeting.Attendee(email: "luis@beamapp.co", name: "Luis"),
        Meeting.Attendee(email: "remi@beamapp.co", name: "Remi")
    ])
    static var previews: some View {
        MeetingModalView(viewModel: model)
            .frame(width: 700, height: 500)
    }
}
