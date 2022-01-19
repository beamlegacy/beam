//
//  CalendarManager.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 12/10/2021.
//

import Foundation
import BeamCore

enum CalendarError: Error {
    case apiScopeNil
    case cantRefreshTokens
    case cantDecode
    case responseDataIsEmpty
    case unknownError(message: String)
}

enum CalendarServices: String {
    case googleCalendar

    var scope: String? {
        switch self {
        case .googleCalendar: return "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/calendar.readonly"
        }
    }
}

protocol CalendarService {
    var id: UUID { get }
    var name: String { get }
    var scope: String? { get }
    var inNeedOfPermission: Bool { get }

    func requestAccess(completionHandler: @escaping (Bool) -> Void)
    func getMeetings(for dateMin: Date, and dateMax: Date?, onlyToday: Bool, query: String?, completionHandler: @escaping (Result<[Meeting]?, CalendarError>) -> Void)
    func getCalendars(completionHandler: @escaping (Result<[MeetingCalendar]?, CalendarError>) -> Void)
    func getUserEmail(completionHandler: @escaping (Result<String, CalendarError>) -> Void)
}

class CalendarManager: ObservableObject {

    let calendarQueue = DispatchQueue(label: "calendarQueue")
    @Published var connectedSources: [CalendarService] = []
    @Published var meetingsForNote = [BeamNote.ID: [Meeting]]()
    @Published var updated: Bool = false

    init() { }

    private var didLazyInitConnectedSources = false

    func lazyInitConnectedSources() {
        guard !didLazyInitConnectedSources else { return }
        didLazyInitConnectedSources = true

        if let googleTokensStr = Persistence.Authentication.googleCalendarTokens,
           let googleTokens = GoogleTokenUtility.objectifyOauth(str: googleTokensStr) {
            for (googleAccessToken, googleRefreshToken) in googleTokens {
                let googleCalendar = GoogleCalendarService(accessToken: googleAccessToken, refreshToken: googleRefreshToken)
                self.connectedSources.append(googleCalendar)
            }
        }
    }

    func isConnected(calendarService: CalendarServices) -> Bool {
        lazyInitConnectedSources()
        guard !connectedSources.isEmpty else {
            return false
        }
        return true
    }

    func requestAccess(from calendarService: CalendarServices, completionHandler: @escaping (Bool) -> Void) {
        lazyInitConnectedSources()
        switch calendarService {
        case .googleCalendar:
            let googleCalendar = GoogleCalendarService(accessToken: nil, refreshToken: nil)
            googleCalendar.requestAccess { [weak self] connected in
                guard let self = self else { return }
                if connected {
                    self.connectedSources.append(googleCalendar)
                }
                completionHandler(connected)
            }
        }
    }

    func getInformation(for source: CalendarService, completionHandler: @escaping (AccountCalendar) -> Void) {
        lazyInitConnectedSources()
        source.getUserEmail { result in
            switch result {
            case .success(let email):
                source.getCalendars { result in
                    switch result {
                    case .success(let meetingsCalendar):
                        completionHandler(AccountCalendar(sourceId: source.id,
                                                          name: email,
                                                          nbrOfCalendar: meetingsCalendar?.count ?? 0,
                                                          meetingCalendar: meetingsCalendar))
                    case .failure: break
                    }
                }
            case .failure: break
            }
        }
    }

    func disconnect(from calendarService: CalendarServices, sourceId: UUID) {
        switch calendarService {
        case .googleCalendar:
            guard let googleCalendarService = self.connectedSources.first(where: { $0.id == sourceId }) as? GoogleCalendarService,
                  let accessToken = googleCalendarService.accessToken,
                  let googleCalendarTokensStr = Persistence.Authentication.googleCalendarTokens,
                  var googleCalendarTokens = GoogleTokenUtility.objectifyOauth(str: googleCalendarTokensStr) else { return }

            if let idx = connectedSources.firstIndex(where: { $0.id == sourceId }) {
                googleCalendarTokens.removeValue(forKey: accessToken)
                Persistence.Authentication.googleCalendarTokens = GoogleTokenUtility.stringifyOauth(dict: googleCalendarTokens)
                connectedSources.remove(at: idx)
                updated = true
            }
        }
    }

    func requestMeetings(for dateMin: Date, and dateMax: Date? = nil, onlyToday: Bool, query: String? = nil, completionHandler: @escaping ([Meeting]) -> Void) {
        var allMeetings: [Meeting] = []
        let dispatchGroup = DispatchGroup()
        lazyInitConnectedSources()
        calendarQueue.async {
            for source in self.connectedSources {
                dispatchGroup.enter()
                source.getMeetings(for: dateMin, and: dateMax, onlyToday: onlyToday, query: query) { result in
                    defer { dispatchGroup.leave() }
                    switch result {
                    case .success(let meetings):
                        guard let sourceMeetings = meetings else { return }
                        allMeetings.append(contentsOf: sourceMeetings)
                    case .failure: break
                    }
                }
            }
            dispatchGroup.notify(queue: .main) {
                completionHandler(allMeetings)
            }
        }
    }
}
