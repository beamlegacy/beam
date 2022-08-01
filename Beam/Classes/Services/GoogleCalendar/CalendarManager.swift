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
    case permissionDenied
    case unknownError(message: String)
}

enum CalendarServices: String {
    case googleCalendar
    case appleCalendar

    var scope: String? {
        switch self {
        case .googleCalendar: return "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/calendar.readonly"
        case .appleCalendar: return nil
        }
    }
}

protocol CalendarService {
    var id: UUID { get }
    var service: CalendarServices { get }
    var name: String { get }
    var scope: String? { get }
    var inNeedOfPermission: Bool { get }
    var hasAuthorization: Bool { get }

    func requestAccess(completionHandler: @escaping (Bool) -> Void)
    func getMeetings(for dateMin: Date, and dateMax: Date?, onlyToday: Bool, query: String?, completionHandler: @escaping (Result<[Meeting]?, CalendarError>) -> Void)
    func getCalendars(completionHandler: @escaping (Result<[MeetingCalendar]?, CalendarError>) -> Void)
    func getAccountName(completionHandler: @escaping (Result<String, CalendarError>) -> Void)
}

extension CalendarService {
    var name: String {
        service.rawValue
    }
    var scope: String? {
        service.scope
    }
}

class CalendarManager: ObservableObject {

    let calendarQueue = DispatchQueue(label: "calendarQueue", target: .database)
    @Published var connectedSources: [CalendarService] = []
    @Published var meetingsForNote = [BeamNote.ID: [Meeting]]()
    @Published var updated: Bool = false

    @UserDefault(key: "showedNotConnectedViewKey", defaultValue: 0)
    var showedNotConnectedView: Int

    init() {
        showedNotConnectedView += 1
    }

    private var didLazyInitConnectedSources = false

    func lazyInitConnectedSources() {
        guard !didLazyInitConnectedSources else { return }
        didLazyInitConnectedSources = true

        if Persistence.Authentication.hasAppleCalendarConnection == true {
            connectedSources.append(AppleCalendarService())
        }
        if let googleTokens = Persistence.Authentication.googleCalendarTokens {
            for (googleAccessToken, googleRefreshToken) in googleTokens {
                let googleCalendar = GoogleCalendarService(accessToken: googleAccessToken, refreshToken: googleRefreshToken)
                self.connectedSources.append(googleCalendar)
            }
        }
    }

    func isConnected(calendarService: CalendarServices) -> Bool {
        lazyInitConnectedSources()
        return connectedSources.contains(where: { $0.service == calendarService })
    }

    func hasConnectedSource() -> Bool {
        lazyInitConnectedSources()
        return !connectedSources.isEmpty
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
        case .appleCalendar:
            let appleCalendar = connectedSources.first(where: { $0.service == .appleCalendar }) ?? AppleCalendarService()
            if appleCalendar.hasAuthorization {
                appleCalendar.requestAccess { [weak self] connected in
                    guard let self = self else { return }
                    if connected && !self.isConnected(calendarService: .appleCalendar) {
                        Persistence.Authentication.hasAppleCalendarConnection = true
                        self.connectedSources.append(appleCalendar)
                    }
                    completionHandler(connected)
                }
            }
        }
    }

    func getInformation(for source: CalendarService, completionHandler: @escaping (AccountCalendar) -> Void) {
        lazyInitConnectedSources()
        source.getAccountName { result in
            switch result {
            case .success(let name):
                source.getCalendars { result in
                    switch result {
                    case .success(let meetingsCalendar):
                        completionHandler(AccountCalendar(sourceId: source.id,
                                                          service: source.service,
                                                          name: name,
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
                  var googleCalendarTokens = Persistence.Authentication.googleCalendarTokens else { return }

            if let idx = connectedSources.firstIndex(where: { $0.id == sourceId }) {
                googleCalendarTokens.removeValue(forKey: accessToken)
                Persistence.Authentication.googleCalendarTokens = googleCalendarTokens
                connectedSources.remove(at: idx)
                updated = true
            }
        case .appleCalendar:
            guard let idx = connectedSources.firstIndex(where: { $0.id == sourceId }) else { return }
            Persistence.Authentication.hasAppleCalendarConnection = false
            connectedSources.remove(at: idx)
            updated = true
        }
    }

    func disconnectAll() {
        self.meetingsForNote.removeAll()
        self.connectedSources.removeAll()
        Persistence.Authentication.googleCalendarTokens = nil
        Persistence.Authentication.hasAppleCalendarConnection = false
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
                completionHandler(self.sortAndRemoveDuplicates(meetings: allMeetings))
            }
        }
    }
}

// MARK: - Calendar Utilities
extension CalendarManager {
    func sortAndRemoveDuplicates(meetings: [Meeting]) -> [Meeting] {
        var meetingsCopy = meetings

        meetingsCopy.sort { meeting1, meeting2 in
            meeting1.startTime < meeting2.startTime
        }

        meetingsCopy = meetingsCopy.reduce([] as [Meeting]) { (res, meeting) -> [Meeting] in
            var res = res
            if res.last != meeting {
                res.append(meeting)
            }
            return res
        }

        return meetingsCopy
    }
}
