//
//  AppleCalendarService.swift
//  Beam
//
//  Created by Frank Lefebvre on 19/05/2022.
//

import Foundation
import BeamCore
import EventKit

final class AppleCalendarService {
    let id = UUID()
    let service = CalendarServices.appleCalendar

    var inNeedOfPermission = true

    private let eventStore = EKEventStore()

    private func getMeetingsWithPermission(for dateMin: Date, and dateMax: Date?, onlyToday: Bool, query: String?, completionHandler: @escaping (Result<[Meeting]?, CalendarError>) -> Void) {
        let endDate = onlyToday ? dateMin.isoCalEndOfDay : dateMax ?? .distantFuture // same behavior as GoogleCalendarService: dateMax is ignored if onlyToday is true
        let predicate = eventStore.predicateForEvents(withStart: dateMin.isoCalStartOfDay, end: endDate, calendars: nil)
        let meetings = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .filter { event in
                guard let query = query else { return true }
                return event.title.contains(query)
            }
            .map { event -> Meeting in
                let name: String = event.title
                let startTime: Date = event.startDate
                let endTime = event.endDate
                let allDayEvent = event.isAllDay
                let attendees = (event.attendees ?? []).map { (attendee: EKParticipant) -> Meeting.Attendee in
                    Meeting.Attendee(email: "", name: attendee.name ?? "")
                }
                return Meeting(name: name, startTime: startTime, endTime: endTime, allDayEvent: allDayEvent, attendees: attendees, htmlLink: event.url?.absoluteString, meetingLink: nil)
            }
            .sorted { meeting1, meeting2 in
                meeting1.startTime < meeting2.startTime
            }
        completionHandler(.success(meetings))
    }
}

extension AppleCalendarService: CalendarService {
    func getAccountName(completionHandler: @escaping (Result<String, CalendarError>) -> Void) {
        completionHandler(.success("macOS Calendar"))
    }

    func requestAccess(completionHandler: @escaping (Bool) -> Void) {
        eventStore.requestAccess(to: .event) { [weak self] granted, error in
            if let error = error {
                Logger.shared.logError("Access to macOS calendars failed: \(error)", category: .eventCalendar)
            }
            self?.inNeedOfPermission = !granted
            DispatchQueue.main.async {
                completionHandler(granted)
            }
        }
    }

    func getMeetings(for dateMin: Date, and dateMax: Date?, onlyToday: Bool, query: String?, completionHandler: @escaping (Result<[Meeting]?, CalendarError>) -> Void) {
        if inNeedOfPermission {
            requestAccess { granted in
                if granted {
                    self.getMeetingsWithPermission(for: dateMin, and: dateMax, onlyToday: onlyToday, query: query, completionHandler: completionHandler)
                } else {
                    completionHandler(.failure(CalendarError.permissionDenied))
                }
            }
        } else {
            getMeetingsWithPermission(for: dateMin, and: dateMax, onlyToday: onlyToday, query: query, completionHandler: completionHandler)
        }
    }

    func getCalendars(completionHandler: @escaping (Result<[MeetingCalendar]?, CalendarError>) -> Void) {
        let calendars = eventStore.calendars(for: .event)
        let result = calendars.map { MeetingCalendar(id: $0.calendarIdentifier, summary: $0.title, description: nil) }
        completionHandler(.success(result))
    }
}
