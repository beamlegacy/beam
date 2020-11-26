import Foundation
import Sentry

class EventsTracker {
    static let shared = EventsTracker()
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }()

    func log(event: Event) {
        let crumb = Breadcrumb(level: .info, category: "event")
        crumb.message = event.rawValue
        SentrySDK.addBreadcrumb(crumb: crumb)

        Logger.shared.logInfo(event.rawValue, category: .tracking)
    }

    func log(event: Event, properties: [String: String]) {
        let crumb = Breadcrumb(level: .info, category: "event")
        crumb.message = event.rawValue
        crumb.data = properties
        SentrySDK.addBreadcrumb(crumb: crumb)

        Logger.shared.logInfo(event.rawValue, category: .tracking)
    }

    func logBreadcrumb(message: String? = nil,
                       category: String = "ui.lifecycle",
                       type: String = "navigation",
                       data: [String: Any]? = nil) {
        let crumb = Breadcrumb(level: .info, category: category)
        crumb.message = message
        crumb.type = type // navigation, system, debug, user
        crumb.data = data // screen: name for uiviewcontroller
        SentrySDK.addBreadcrumb(crumb: crumb)
    }

    //swiftlint:disable function_body_length
    func enrichUserInfos() {
        if let userid = Persistence.Authentication.userId, let email = Persistence.Authentication.email {
            LibrariesManager.shared.setSentryUser(userID: userid, email: email)
        }
    }
}

// MARK: - Events
extension EventsTracker {
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
