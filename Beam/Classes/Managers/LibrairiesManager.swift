import Foundation
import os.log
import Sentry

/// Hold all external librairies needing initialisation (ex: sentry, firebase, etc). Is also used to raise non fatal errors
/// `configure()` is called on app launch.
class LibrariesManager: NSObject {
    static let shared = LibrariesManager()

    var sentryUser: Sentry.User?

    func configure() {
        setupSentry()
    }
}

extension LibrariesManager {
    func setupSentry() {
        guard Configuration.sentryEnabled else {
            Logger.shared.logDebug("Sentry is disabled", category: .general)
            return
        }
        SentrySDK.start(options: [
            "dsn": "https://\(Configuration.sentryKey)@\(Configuration.sentryHostname)/\(Configuration.sentryProject)",
            "debug": false,
            "sampleRate": 1.0,
            "enableAutoSessionTracking": true,
            "release": Information.appVersionAndBuild
        ])
        setupSentryScope()
        setSentryUser()
    }

    func setupSentryScope() {
        SentrySDK.configureScope { scope in
            scope.setEnvironment(Configuration.env)
            scope.setDist(Information.appBuild)
        }
    }

    func setSentryUser() {
        guard let email = Persistence.Authentication.email else { return }
        let user = Sentry.User()
        user.email = email
        SentrySDK.setUser(user)
        sentryUser = user
    }
}

extension LibrariesManager {
    // Can be called either with an Error, or with a description and an optional info dictionnary
    static func nonFatalError(_ description: String = "", error: Error? = nil, addedInfo: [String: Any]? = nil) {
        let finalDescription = "\(description) \(error?.localizedDescription ?? "")".trimmingCharacters(in: .whitespaces)
        Logger.shared.logError("nonFatalError \(finalDescription)", category: .general)
    }
}
