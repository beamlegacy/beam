//
//  AppleCalendarService.swift
//  Beam
//
//  Created by Frank Lefebvre on 19/05/2022.
//

import Foundation
import BeamCore
import EventKit
import Contacts

final class AppleCalendarService {
    let id = UUID()
    let service = CalendarServices.appleCalendar

    var inNeedOfPermission = true

    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()

    private func getMeetingsWithCalendarPermission(for dateMin: Date, and dateMax: Date?, onlyToday: Bool, query: String?, completionHandler: @escaping (Result<[Meeting]?, CalendarError>) -> Void) {
        contactStore.requestAccess(for: .contacts) { _, _ in
            self.getMeetingsWithPermission(for: dateMin, and: dateMax, onlyToday: onlyToday, query: query, completionHandler: completionHandler)
        }
    }

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
                let attendees = (event.attendees ?? [])
                    .filter { $0.participantType == .person || $0.participantType == .group }
                    .map { (attendee: EKParticipant) -> Meeting.Attendee in
                        Meeting.Attendee(email: attendee.participantEmail ?? "", name: attendee.participantName(from: contactStore) ?? "")
                    }
                return Meeting(name: name, startTime: startTime, endTime: endTime, allDayEvent: allDayEvent, attendees: attendees, htmlLink: event.url?.absoluteString, meetingLink: event.meetingLink)
            }
            .sorted { meeting1, meeting2 in
                meeting1.startTime < meeting2.startTime
            }
        completionHandler(.success(meetings))
    }
}

private extension EKEvent {
    var meetingLink: String? {
        if let url = url {
            return url.absoluteString
        }

        guard let notes = notes else { return nil }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        guard let matches = detector?.matches(in: notes, options: [], range: NSRange(location: 0, length: notes.utf16.count)) else { return nil }

        for match in matches {
            guard let range = Range(match.range, in: notes) else { continue }
            let url = notes[range]
            if url.contains("meet.google") {
                return String(url)
            }
            if url.contains("zoom.us") {
                return String(url)
            }
        }

        return nil
    }
}

private extension EKParticipant {
    func participantName(from contactStore: CNContactStore) -> String? {
        do {
            let contacts: [CNContact] = try contactStore.unifiedContacts(matching: contactPredicate, keysToFetch: [CNContactFormatter.descriptorForRequiredKeys(for: .fullName)])
            if let contact = contacts.first {
                return CNContactFormatter().string(from: contact)
            }
        } catch {}
        return name?.split(separator: "@").first.map(String.init)
    }

    var participantEmail: String? {
        url.absoluteStringWithoutScheme?.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
    }
}

extension AppleCalendarService: CalendarService {
    internal var hasAuthorization: Bool {
        let status = EKEventStore.authorizationStatus(for: EKEntityType.event)
        switch status {
        case EKAuthorizationStatus.restricted, EKAuthorizationStatus.denied:
            UserAlert.showMessage(message: "Beam would like to access you calendar", informativeText: nil, buttonTitle: "Ok", secondaryButtonTitle: "Cancel",
                                  buttonAction: {
                let prefsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
                NSWorkspace.shared.open(prefsURL)
            })
            return false
        case .authorized, .notDetermined:
            return true
        @unknown default:
            break
        }
        return false
    }

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
                    self.getMeetingsWithCalendarPermission(for: dateMin, and: dateMax, onlyToday: onlyToday, query: query, completionHandler: completionHandler)
                } else {
                    completionHandler(.failure(CalendarError.permissionDenied))
                }
            }
        } else {
            getMeetingsWithCalendarPermission(for: dateMin, and: dateMax, onlyToday: onlyToday, query: query, completionHandler: completionHandler)
        }
    }

    func getCalendars(completionHandler: @escaping (Result<[MeetingCalendar]?, CalendarError>) -> Void) {
        let calendars = eventStore.calendars(for: .event)
        let result = calendars.map { MeetingCalendar(id: $0.calendarIdentifier, summary: $0.title, description: nil) }
        completionHandler(.success(result))
    }
}
