import Foundation
import Sentry

public class EventsTracker {
    public static func log(event: Event) {
        let crumb = Breadcrumb(level: .info, category: "event")
        crumb.message = event.rawValue
        SentrySDK.addBreadcrumb(crumb: crumb)

        Logger.shared.logInfo(event.rawValue, category: .tracking)
    }

    public static func log(event: Event, properties: [String: String]) {
        let crumb = Breadcrumb(level: .info, category: "event")
        crumb.message = event.rawValue
        crumb.data = properties
        SentrySDK.addBreadcrumb(crumb: crumb)

        Logger.shared.logInfo(event.rawValue, category: .tracking)
    }

    public static func logBreadcrumb(level: SentryLevel = .debug, message: String, category: String, type: String? = nil, data: [String: Any]? = nil) {
        #if TEST || DEBUG
        let crumb = Breadcrumb()
        crumb.level = level
        crumb.category = category
        crumb.message = message
        crumb.type = type
        crumb.data = data
        SentrySDK.addBreadcrumb(crumb: crumb)
        #endif
    }

    public static func sendManualReport(forError error: Error) {
        SentrySDK.capture(error: error)
    }

}

// MARK: - Events
public extension EventsTracker {
    enum Event: String, CaseIterable {
        // App livecycle
        case appLaunch = "APP_LAUNCH"
        case appActive = "APP_ACTIVE"
        case appInactive = "APP_INACTIVE"

        // Login
        case signIn = "SIGN_IN"

        // General
        case termsOfService = "TERMS_OF_SERVICE"
        case signedOut = "SIGNED_OUT"
    }
}
