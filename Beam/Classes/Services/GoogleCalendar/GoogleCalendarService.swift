//
//  GoogleCalendarService.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 30/09/2021.
//

import Foundation
import BeamCore
import OAuthSwift
import SwiftUI

// Google Calendar API Reference: https://developers.google.com/calendar/api/v3/reference
enum GoogleCalendarEndPoints {
    case calendarList
    case calendar(id: String)
    case calendarEvents(calendarId: String)
    case eventDetails(calendarId: String, eventId: String)

    var url: String {
        switch self {
        case .calendarList: return "https://www.googleapis.com/calendar/v3/users/me/calendarList"
        case .calendar(let id): return "https://www.googleapis.com/calendar/v3/calendars/\(id)"
        case .calendarEvents(let calendarId): return "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events"
        case .eventDetails(let calendarId, let eventId): return "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events/\(eventId)"
        }
    }
}

class GoogleCalendarService {
    var name: String = CalendarServices.googleCalendar.rawValue
    var scope: String? = CalendarServices.googleCalendar.scope
    var inNeedOfPermission: Bool = false

    var calendarList: GoogleCalendarList?

    let authClient = OAuth2Swift(
        consumerKey: EnvironmentVariables.Oauth.Google.consumerKey,
        consumerSecret: EnvironmentVariables.Oauth.Google.consumerSecret,
        authorizeUrl: "https://accounts.google.com/o/oauth2/auth",
        accessTokenUrl: "https://accounts.google.com/o/oauth2/token",
        responseType: "code"
    )

    init() {}

    private func getCalendarList(refreshedToken: Bool = false, completionHandler: @escaping (Result<GoogleCalendarList, Error>) -> Void) {
        // GET https://www.googleapis.com/calendar/v3/users/me/calendarList
        requestGoogleCalendar(path: GoogleCalendarEndPoints.calendarList.url) { result in
            switch result {
            case .success(let data):
                guard let responseData = data else {
                    completionHandler(.failure(CalendarError.responseDataIsEmpty))
                    return
                }
                let decoder = JSONDecoder()
                guard let calendarList = try? decoder.decode(GoogleCalendarList.self, from: responseData) else {
                    completionHandler(.failure(CalendarError.cantDecode))
                    return
                }
                completionHandler(.success(calendarList))
            case .failure(let error):
                //tokenExpired
                if error._code == -2 && !refreshedToken {
                    self.refreshToken(completionHandler: { result in
                        switch result {
                        case .failure:
                            completionHandler(.failure(CalendarError.cantRefreshTokens))
                        case .success:
                            self.getCalendarList(refreshedToken: true, completionHandler: { result in
                                completionHandler(result)
                            })
                        }
                    })
                } else {
                    completionHandler(.failure(CalendarError.unknownError(message: error.localizedDescription)))
                }
            }
        }
    }

    private func getCalendar(with id: String?, refreshedToken: Bool = false, completionHandler: @escaping (Result<GoogleCalendar, Error>) -> Void) {
        // GET https://www.googleapis.com/calendar/v3/calendars/calendarId
        requestGoogleCalendar(path: GoogleCalendarEndPoints.calendar(id: id ?? "primary").url) { result in
            switch result {
            case .success(let data):
                guard let responseData = data else {
                    completionHandler(.failure(CalendarError.responseDataIsEmpty))
                    return
                }
                let decoder = JSONDecoder()
                guard let calendar = try? decoder.decode(GoogleCalendar.self, from: responseData) else {
                    completionHandler(.failure(CalendarError.cantDecode))
                    return
                }
                completionHandler(.success(calendar))
            case .failure(let error):
                //tokenExpired
                if error._code == -2 && !refreshedToken {
                    self.refreshToken(completionHandler: { result in
                        switch result {
                        case .failure:
                            completionHandler(.failure(CalendarError.cantRefreshTokens))
                        case .success:
                            self.getCalendar(with: id, refreshedToken: true, completionHandler: { result in
                                completionHandler(result)
                            })
                        }
                    })
                } else {
                    completionHandler(.failure(CalendarError.unknownError(message: error.localizedDescription)))
                }
            }
        }
    }

    private func getCalendarEvents(with calendarId: String?, for parameters: [String: Any], refreshedToken: Bool = false, completionHandler: @escaping (Result<GoogleEventList, CalendarError>) -> Void) {
        // GET https://www.googleapis.com/calendar/v3/calendars/calendarId/events
        requestGoogleCalendar(path: GoogleCalendarEndPoints.calendarEvents(calendarId: calendarId ?? "primary").url, parameters: parameters) { result in
            switch result {
            case .success(let data):
                guard let responseData = data else {
                    completionHandler(.failure(CalendarError.responseDataIsEmpty))
                    return
                }
                let decoder = JSONDecoder()
                guard let eventList = try? decoder.decode(GoogleEventList.self, from: responseData) else {
                    completionHandler(.failure(CalendarError.cantDecode))
                    return
                }
                completionHandler(.success(eventList))
            case .failure(let error):
                //tokenExpired
                if error._code == -2 && !refreshedToken {
                    self.refreshToken(completionHandler: { result in
                        switch result {
                        case .failure:
                            completionHandler(.failure(CalendarError.cantRefreshTokens))
                        case .success:
                            self.getCalendarEvents(with: calendarId, for: parameters, refreshedToken: true, completionHandler: { result in
                                completionHandler(result)
                            })
                        }
                    })
                } else {
                    completionHandler(.failure(CalendarError.unknownError(message: error.localizedDescription)))
                }
            }
        }
    }

    // Not needed atm
    private func getEventDetails(with calendarId: String?, and eventId: String) {
        // GET https://www.googleapis.com/calendar/v3/calendars/calendarId/events/eventId
        requestGoogleCalendar(path: GoogleCalendarEndPoints.eventDetails(calendarId: calendarId ?? "primary", eventId: eventId).url) { _ in
        }
    }

    private func buildRequestParameters(for dateMin: Date?, and dateMax: Date?, onlyToday: Bool?, query: String?) -> [String: Any] {
        var parameters: [String: Any] = ["orderBy": "startTime", "singleEvents": true]
        if let dateMin = dateMin {
            parameters["timeMin"] = dateMin.isoCalStartOfDay.iso8601withFractionalSeconds
        }
        if let dateMax = dateMax {
            parameters["timeMax"] = dateMax.isoCalStartOfDay.iso8601withFractionalSeconds
        }
        if let onlyToday = onlyToday, onlyToday, let dateMin = dateMin {
            parameters["timeMax"] = dateMin.isoCalEndOfDay.iso8601withFractionalSeconds
        }
        if let query = query {
            parameters["q"] = query
        }
        return parameters
    }

    private func requestGoogleCalendar(path: String, parameters: [String: Any] = ["": ""], completionHandler: @escaping (Result<Data?, OAuthSwiftError>) -> Void) {
        guard let accessToken = Persistence.Authentication.googleAccessToken else {
            completionHandler(.failure(OAuthSwiftError.missingToken))
            return
        }

        let headers = ["Authorization": "Bearer \(accessToken)"]
        authClient.client.get(path, parameters: parameters, headers: headers) { result in
            switch result {
            case .success(let response):
//                Logger.shared.logDebug("JSON String: \(String(describing: try? response.jsonObject())))", category: .googleCalendar)
                completionHandler(.success(response.data))
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .eventCalendar)
                completionHandler(.failure(error))
            }
        }
    }

    private func refreshToken(completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        guard let refreshToken = Persistence.Authentication.googleRefreshToken else {
            Logger.shared.logError("The refreshToken operation couldn’t be completed since googleRefreshToken is nil", category: .eventCalendar)
            return
        }

        authClient.renewAccessToken(withRefreshToken: refreshToken, parameters: .none, headers: .none) { result in
            switch result {
            case .success(let response):
                Persistence.Authentication.googleRefreshToken = response.credential.oauthRefreshToken
                Persistence.Authentication.googleAccessToken = response.credential.oauthToken
                completionHandler(.success(true))
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .eventCalendar)
                completionHandler(.failure(error))
            }
        }
    }

    private func requestGoogleCalendarScopeAccess(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        guard let scope = scope else {
            completionHandler(.failure(CalendarError.apiScopeNil))
            return
        }
        let window = AppDelegate.main.openOauthWindow(title: IdentityRequest.Provider.google.rawValue.capitalized)
        let oauthController = window.oauthController
        authClient.authorizeURLHandler = oauthController

        let state = generateState(withLength: 20)

        authClient.authorize(
            withCallbackURL: EnvironmentVariables.Oauth.Google.callbackURL,
            scope: scope,
            state: state) { result in
            switch result {
            case .success(let (credential, _, _)):
                Persistence.Authentication.googleAccessToken = credential.oauthToken
                Persistence.Authentication.googleRefreshToken = credential.oauthRefreshToken
                self.inNeedOfPermission = false
                completionHandler(.success(()))
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .network)
                self.inNeedOfPermission = true
                completionHandler(.failure(error))
            }
        }
    }

    private func convertApiObject(eventList: GoogleEventList) -> [Meeting] {
        let dateFormatter = ISO8601DateFormatter()
        var meetings: [Meeting] = []

        let acceptedEventList = eventList.events.filter { event in
            guard let attendees = event.attendees else { return true }
            return attendees.contains(where: {$0.`self` == true && $0.responseStatus == "accepted"})
        }

        for event in acceptedEventList {
            guard let eventSummary = event.summary, let startTime = event.startDate?.dateTime, let date = dateFormatter.date(from: startTime) else { continue }
            var meetingAttendees: [Meeting.Attendee] = []
            if let attendees = event.attendees {
                for attendee in attendees where attendee.`self` != true {
                    meetingAttendees.append(Meeting.Attendee(email: attendee.email ?? "", name: attendee.displayName ?? ""))
                }
            }
            meetings.append(Meeting(name: eventSummary, startTime: date, attendees: meetingAttendees, linkCards: true))
        }
        return meetings
    }
}

extension GoogleCalendarService: CalendarService {
    func getMeetings(for dateMin: Date, and dateMax: Date?, onlyToday: Bool, query: String?, completionHandler: @escaping (Result<[Meeting]?, CalendarError>) -> Void) {
        let parameters = buildRequestParameters(for: dateMin, and: dateMax, onlyToday: onlyToday, query: query)
        getCalendarEvents(with: nil, for: parameters) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let eventList):
                completionHandler(.success(self.convertApiObject(eventList: eventList)))
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .eventCalendar)
                self.inNeedOfPermission = true
                completionHandler(.failure(error))
            }
        }
    }

    func requestAccess(completionHandler: @escaping (Bool) -> Void) {
        requestGoogleCalendarScopeAccess { result in
            switch result {
            case .success: completionHandler(true)
            case .failure: completionHandler(false)
            }
        }
    }
}
