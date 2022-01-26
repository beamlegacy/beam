import Foundation
import BeamCore
import Sentry

/// Hold all external librairies needing initialisation (ex: sentry, firebase, etc). Is also used to raise non fatal errors
/// `configure()` is called on app launch.
class ThirdPartyLibrariesManager: NSObject {
    static let shared = ThirdPartyLibrariesManager()

    var sentryUser: Sentry.User?

    func configure() {
        setupSentry()
        setupFirebase()
    }

    func updateUser() {
        setSentryUser()
        setFirebaseUser()
    }
}

extension ThirdPartyLibrariesManager {
    // Can be called either with an Error, or with a description and an optional info dictionnary
    func nonFatalError(_ description: String = "", error: Error? = nil, addedInfo: [String: Any]? = nil) {
        let finalDescription = "\(description) \(error?.localizedDescription ?? "")".trimmingCharacters(in: .whitespaces)
        Logger.shared.logError("nonFatalError \(finalDescription)", category: .general)
    }
}
