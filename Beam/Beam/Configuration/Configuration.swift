import Foundation

// This file handles any configuration parameters
// Build configuration variables are defined in xcconfig files, feed Info.plist then accessed from here
// File is parsed by https://github.com/penso/variable-injector

struct Configuration {
    // Build configuration
    static private(set) var bundleIdentifier: String = Configuration.value(for: "CFBundleIdentifier")
    static private(set) var sentryKey = "$(SENTRY_KEY)"
    static private(set) var sentryHostname = "$(SENTRY_HOSTNAME)"
    static private(set) var sentryProject = "$(SENTRY_PROJECT)"
    static private(set) var env = "$(ENV)"

    // Runtime configuration
    static private(set) var apiBaseUrl = "$(API_BASE_URL)"
    static private(set) var publicHostname = "$(PUBLIC_HOSTNAME)"

    static private func value<T>(for key: String) -> T {
        guard let value = Bundle.main.infoDictionary?[key] as? T else {
            fatalError("Invalid or missing Info.plist key: \(key)")
        }
        return value
    }
}
