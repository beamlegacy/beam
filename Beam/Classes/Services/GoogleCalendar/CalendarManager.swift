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
        case .googleCalendar: return "https://www.googleapis.com/auth/calendar.readonly"
        }
    }
}

protocol CalendarService {
    var name: String { get }
    var scope: String? { get }
    var inNeedOfPermission: Bool { get }

    func requestAccess(completionHandler: @escaping (Bool) -> Void)
    func getMeetings(for dateMin: Date, and dateMax: Date?, onlyToday: Bool, query: String?, completionHandler: @escaping (Result<[Meeting]?, CalendarError>) -> Void)
}

class CalendarManager: ObservableObject {

    let calendarQueue = DispatchQueue(label: "calendarQueue")
    @Published var connectedSources: [CalendarService] = []
    @Published var meetingsForNote = [BeamNote.ID: [Meeting]]()
    @Published var didAllowSource: Bool = false

    init() { }

    private var didLazyInitConnectedSources = false
    func lazyInitConnectedSources() {
        guard !didLazyInitConnectedSources else { return }
        didLazyInitConnectedSources = true
        if Persistence.Authentication.googleAccessToken != nil && Persistence.Authentication.googleRefreshToken != nil {
            let googleCalendar = GoogleCalendarService()
            self.connectedSources.append(googleCalendar)
        }
    }

    func isConnected(calendarService: CalendarServices) -> Bool {
        guard AuthenticationManager.shared.isAuthenticated else { return false }
        lazyInitConnectedSources()
        guard let connectedSource = connectedSources.first(where: { $0.name == calendarService.rawValue }), !connectedSource.inNeedOfPermission else {
            return false
        }
        return true
    }

    func connect(calendarService: CalendarServices) {
        lazyInitConnectedSources()
        switch calendarService {
        case .googleCalendar:
            let googleCalendar = GoogleCalendarService()
            googleCalendar.inNeedOfPermission = true
            self.connectedSources.append(googleCalendar)
        }
    }

    func disconnect(calendarService: CalendarServices) {
        lazyInitConnectedSources()
        switch calendarService {
        case .googleCalendar:
            self.connectedSources = self.connectedSources.filter({$0.name != calendarService.rawValue})
        }
    }

    func requestAccess(from calendarService: CalendarServices, completionHandler: @escaping (Bool) -> Void) {
        lazyInitConnectedSources()
        switch calendarService {
        case .googleCalendar:
            let googleCalendar = GoogleCalendarService()
            googleCalendar.requestAccess { [weak self] connected in
                guard let self = self else { return }
                if connected {
                    if let connectedSource = self.connectedSources.first(where: { $0.name == calendarService.rawValue }) as? GoogleCalendarService {
                        connectedSource.inNeedOfPermission = false
                        self.didAllowSource = true
                    } else {
                        self.connectedSources.append(googleCalendar)
                    }
                }
                completionHandler(connected)
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
                    case .failure(let error):
                        Logger.shared.logError(error.localizedDescription, category: .eventCalendar)
                    }
                }
            }
            dispatchGroup.notify(queue: .main) {
                completionHandler(allMeetings)
             }
        }
    }
}
