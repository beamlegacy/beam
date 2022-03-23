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
    var account: AccountCalendar? { get set }
    var scope: String? { get }
    var inNeedOfPermission: Bool { get }

    func requestAccess(completionHandler: @escaping (Bool) -> Void)
    func getMeetings(of calendar: String?, for dateMin: Date, and dateMax: Date?, onlyToday: Bool, query: String?, completionHandler: @escaping (Result<[Meeting]?, CalendarError>) -> Void)
    func getCalendars(completionHandler: @escaping (Result<[MeetingCalendar]?, CalendarError>) -> Void)
    func getUserEmail(completionHandler: @escaping (Result<String, CalendarError>) -> Void)
}

class CalendarManager: ObservableObject {

    let calendarQueue = DispatchQueue(label: "calendarQueue")
    @Published var connectedSources: [CalendarService] = []
    @Published var meetingsForNote = [BeamNote.ID: [Meeting]]()
    @Published var updated: Bool = false

    @UserDefault(key: "showedNotConnectedViewKey", defaultValue: 0)
    var showedNotConnectedView: Int

    init() {
        showedNotConnectedView += 1
    }

    private var didLazyInitConnectedSources = false

    func lazyInitConnectedSources(completionHandler: @escaping () -> Void) {
        guard !didLazyInitConnectedSources else {
            completionHandler()
            return
        }
        didLazyInitConnectedSources = true

        if let googleTokens = Persistence.Authentication.googleCalendarTokens {
            for (googleAccessToken, googleRefreshToken) in googleTokens {
                let googleCalendar = GoogleCalendarService(accessToken: googleAccessToken, refreshToken: googleRefreshToken)
                self.getInformation(for: googleCalendar) { accountCalendar in
                    googleCalendar.account = accountCalendar
                    self.connectedSources.append(googleCalendar)
                    completionHandler()
                }
            }
        }
    }

    func isConnected(calendarService: CalendarServices, completionHandler: @escaping (Bool) -> Void) {
        lazyInitConnectedSources { [weak self] in
            guard let self = self, !self.connectedSources.isEmpty else {
                completionHandler(false)
                return
            }
            completionHandler(true)
        }
    }

    func requestAccess(from calendarService: CalendarServices, completionHandler: @escaping (Bool) -> Void) {
        switch calendarService {
        case .googleCalendar:
            let googleCalendar = GoogleCalendarService(accessToken: nil, refreshToken: nil)
            googleCalendar.requestAccess { [weak self] connected in
                guard let self = self else { return }
                if connected {
                    self.getInformation(for: googleCalendar) { accountCalendar in
                        googleCalendar.account = accountCalendar
                        self.connectedSources.append(googleCalendar)
                        completionHandler(connected)
                    }
                }
                completionHandler(connected)
            }
        }
    }

    func getInformation(for source: CalendarService, completionHandler: @escaping (AccountCalendar) -> Void) {
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
                  var googleCalendarTokens = googleCalendarService.googleTokens else { return }

            if let idx = connectedSources.firstIndex(where: { $0.id == sourceId }) {
                googleCalendarTokens.removeValue(forKey: accessToken)
                googleCalendarService.googleTokens = googleCalendarTokens
                connectedSources.remove(at: idx)
                updated = true
            }
        }
    }

    func requestMeetings(for dateMin: Date, and dateMax: Date? = nil, onlyToday: Bool, query: String? = nil, completionHandler: @escaping ([Meeting]) -> Void) {
        var allMeetings: [Meeting] = []
        let dispatchGroup = DispatchGroup()
        lazyInitConnectedSources { [weak self] in
            guard let self = self else { return }
            self.calendarQueue.sync {
                for source in self.connectedSources {
                    guard let calendars = source.account?.meetingCalendar else { return }
                    for calendar in calendars {
                        dispatchGroup.enter()
                        source.getMeetings(of: calendar.id, for: dateMin, and: dateMax, onlyToday: onlyToday, query: query) { result in
                            defer { dispatchGroup.leave() }
                            switch result {
                            case .success(let meetings):
                                guard let sourceMeetings = meetings, !sourceMeetings.isEmpty else { return }
                                allMeetings.append(contentsOf: sourceMeetings)
                            case .failure: break
                            }
                        }
                    }
                }
                dispatchGroup.notify(queue: .main) {
                    completionHandler(allMeetings)
                }
            }
        }
    }
}
