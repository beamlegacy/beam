import Foundation
import os.log
import Sentry
import BeamCore

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
            Logger.shared.logDebug("Sentry is disabled", category: .sentry)
            return
        }

        Logger.shared.logDebug("Sentry enabled: https://\(Configuration.sentryKey[0..<3])...@\(Configuration.sentryHostname)/\(Configuration.sentryProject)",
                               category: .sentry)

        SentrySDK.start { options in
            options.dsn = "https://\(Configuration.sentryKey)@\(Configuration.sentryHostname)/\(Configuration.sentryProject)"
            options.beforeSend = { event in
                Logger.shared.logDebug("Event: \(event.type ?? "-") \(event.level) \(event.message?.message ?? "-")",
                                       category: .sentry)
                return event
            }
            options.beforeBreadcrumb = { event in
                Logger.shared.logDebug("Breadcrumb: \(event.type ?? "-") \(event.category) \(event.message ?? "-") \(event.data?.description ?? "-")",
                                       category: .sentry)
                return event
            }
            options.debug = false
            options.tracesSampleRate = 1.0
            options.releaseName = Information.appVersionAndBuild
        }

        setupSentryScope()
        setSentryUser()
    }

    func setupSentryScope() {
        let currentHost = Host.current().name ?? ""
        SentrySDK.configureScope { scope in
            scope.setEnvironment(Configuration.env)
            scope.setDist(Information.appBuild)
            scope.setTag(value: currentHost, key: "hostname")

            if let mergeRequestSourceBranche = ProcessInfo.processInfo.environment["CI_MERGE_REQUEST_SOURCE_BRANCH_NAME"] {
                scope.setTag(value: mergeRequestSourceBranche, key: "MERGE_REQUEST")
            }
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
