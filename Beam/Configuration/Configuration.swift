import Foundation

// This file handles any configuration parameters
// Build configuration variables are defined in xcconfig files, feed Info.plist then accessed from here
// File is parsed by https://github.com/penso/variable-injector

/*
 *
 * * * * * * * * *
  IMPORTANT: Save this file and commit when you change it before building or you will lose your changes.
 
  Building will overwrite this file to inject the ENV variables.
 * * * * * * * * *
 */

struct Configuration {
    // Build configuration
    static private(set) var bundleIdentifier: String = Configuration.value(for: "CFBundleIdentifier")
    static private(set) var sentryKey = "$(SENTRY_KEY)"
    static private(set) var sentryHostname = "o477543.ingest.sentry.io"
    static private(set) var sentryProject = "5518785"
    static private(set) var env = "$(ENV)"

    // Runtime configuration
    static private(set) var apiHostnameDefault = "api.beamapp.co"
    static private(set) var publicHostnameDefault = "app.beamapp.co"

    static private var apiHostnameKey = "apiHostname"
    static var apiHostname: String {
        get {
            UserDefaults.standard.string(forKey: apiHostnameKey) ?? apiHostnameDefault
        }
        set {
            if newValue != apiHostname {
                UserDefaults.standard.set(newValue, forKey: apiHostnameKey)
                AccountManager.logout()
            }
        }
    }

    static private var publicHostnameKey = "publicHostname"
    static var publicHostname: String {
        get {
            UserDefaults.standard.string(forKey: publicHostnameKey) ?? publicHostnameDefault
        }
        set {
            if newValue != publicHostname {
                UserDefaults.standard.set(newValue, forKey: publicHostnameKey)
                AccountManager.logout()
            }
        }
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: publicHostnameKey)
        UserDefaults.standard.removeObject(forKey: apiHostname)
    }

    static private func value<T>(for key: String) -> T {
        guard let value = Bundle.main.infoDictionary?[key] as? T else {
            fatalError("Invalid or missing Info.plist key: \(key)")
        }
        return value
    }
}
