//
//  MeetingsListView.swift
//  Beam
//
//  Created by Remi Santos on 05/10/2021.
//

import SwiftUI
import BeamCore
import Combine

struct MeetingsForDay: Identifiable {
    var id: String {
        date.iso8601withFractionalSeconds
    }
    var date: Date
    var meetings: [Meeting]
}

struct MeetingsListView: View {

    var meetingsByDay: [MeetingsForDay]
    @Binding var selectedMeeting: Meeting?
    var searchQuery: String = ""
    var isLoading = false

    @State private var maxTimeWidth: CGFloat = 0
    @State private var isHovering: Bool = false
    @State private var hoveredMeeting: Meeting?

    private static var dayFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }

    private static var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }

    private func timeString(from date: Date) -> String {
        let time = Self.timeFormatter.string(from: date)
        return time.first == "0" ? time.substring(from: 1, to: time.count) : time
    }

    private func backgroundColor(selected: Bool, hovering: Bool) -> Color? {
        guard selected || hovering else { return nil }
        return BeamColor.Beam.swiftUI.opacity(0.1)
    }

    private func highlightedTextRanges(in text: String) -> [Range<String.Index>] {
        guard !searchQuery.isEmpty else { return [] }
        return text.ranges(of: searchQuery, options: .caseInsensitive)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading || meetingsByDay.isEmpty {
                Text(isLoading ? "Loading..." : "No Results")
                    .font(BeamFont.regular(size: 12).swiftUI)
                    .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                    .padding(.top, BeamSpacing._50)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(meetingsByDay, id: \.id) { meetingsForDay in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(Self.dayFormatter.string(from: meetingsForDay.date))
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                            .padding(.top, 2)
                            .padding(.leading, 6)
                        VStack(alignment: .leading) {
                            ForEach(meetingsForDay.meetings, id: \.id) { meeting in
                                let isSelected = meeting.id == selectedMeeting?.id
                                let time = timeString(from: meeting.startTime)
                                HStack(spacing: 5) {
                                    Text(time)
                                        .foregroundColor(isSelected ? BeamColor.Beam.swiftUI : BeamColor.LightStoneGray.swiftUI)
                                        .blendMode(.multiply)
                                        .frame(width: maxTimeWidth, alignment: .trailing)
                                    StyledText(verbatim: meeting.name)
                                        .style(.font(BeamFont.semibold(size: 13).swiftUI), ranges: highlightedTextRanges)
                                        .lineLimit(1)
                                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                                    Spacer(minLength: 0)
                                    if isSelected {
                                        Icon(name: "shortcut-return", size: 12, color: BeamColor.LightStoneGray.swiftUI)
                                    }
                                }
                                .font(BeamFont.regular(size: 13).swiftUI)
                                .padding(.horizontal, BeamSpacing._100)
                                .padding(.vertical, BeamSpacing._80)
                                .frame(height: 32)
                                .background(backgroundColor(selected: isSelected, hovering: hoveredMeeting?.id == meeting.id))
                                .background(Text(time)
                                                .background(GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: TimeWidthPreferenceKey.self,
                                        value: geometry.size.width + 2
                                    )
                                })
                                                .hidden()
                                )
                                .cornerRadius(6)
                                .onHover { h in
                                    hoveredMeeting = h ? meeting : nil
                                }
                                .onTapGesture {
                                    selectedMeeting = meeting
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, BeamSpacing._80)
        .padding(.vertical, BeamSpacing._50)
        .onPreferenceChange(TimeWidthPreferenceKey.self) {
            maxTimeWidth = $0
        }
    }

    private struct TimeWidthPreferenceKey: PreferenceKey {
        static let defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

}

struct MeetingsListView_Previews: PreviewProvider {
    static var selectedMeeting = Meeting(name: "Snack", startTime: BeamDate.now, endTime: BeamDate.now, attendees: [])
    static var previews: some View {
        MeetingsListView(meetingsByDay: [
            MeetingsForDay(date: BeamDate.now, meetings: [
                Meeting(name: "Yeah sure", startTime: BeamDate.now, endTime: BeamDate.now.addingTimeInterval(-30000), attendees: []),
                selectedMeeting
            ]),
            MeetingsForDay(date: BeamDate.now.addingTimeInterval(150000), meetings: [
                Meeting(name: "Ouiiiii", startTime: BeamDate.now, endTime: BeamDate.now.addingTimeInterval(10000), attendees: [])
            ])
        ], selectedMeeting: .constant(selectedMeeting), isLoading: true)
        .background(BeamColor.Generic.background.swiftUI)
        .frame(width: 240, height: 200)
    }
}
