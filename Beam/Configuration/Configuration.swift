import Foundation
import BeamCore

struct Configuration {
    // Build configuration
    static private(set) var bundleIdentifier: String = Configuration.value(for: "CFBundleIdentifier")
    static private(set) var sentryKey = EnvironmentVariables.Sentry.key
    static private(set) var sentryHostname = "o477543.ingest.sentry.io"
    static private(set) var sentryProject = "5518785"
    static private(set) var env = EnvironmentVariables.env
    static private(set) var testAccountEmail = EnvironmentVariables.Account.testEmail
    static private(set) var testAccountPassword = EnvironmentVariables.Account.testPassword
    static private(set) var autoUpdate = EnvironmentVariables.autoUpdate
    static private(set) var networkStubs = EnvironmentVariables.networkStubs
    static private(set) var updateFeedURL: String = Configuration.value(for: "SUFeedURL")
    static private(set) var sentryEnabled = EnvironmentVariables.sentryEnabled
    static private(set) var networkEnabledDefault = EnvironmentVariables.networkEnabled
    static private(set) var topDomainDBMaxSize = 10000
    static private(set) var beamObjectDataOnSeparateCall = true
    static private(set) var uiTestModeLaunchArgument = "XCUITest"
    static private(set) var unitTestModeLaunchArgument = "test"

    static private(set) var sentryDsn = "https://\(sentryKey)@\(sentryHostname)/\(sentryProject)"

    static private(set) var testPrivateKey = "j6tifPZTjUtGoz+1RJkO8dOMlu48MUUSlwACw/fCBw0="

    static var shouldDeleteEmptyDatabase = true

    // Runtime configuration
    // Set to "http://api.beam.lvh.me:5000" for running on a local API instance
    static private(set) var apiHostnameDefault = "https://api.beamapp.co" // "http://api.beam.lvh.me"
    static private(set) var publicHostnameDefault = "https://app.beamapp.co"

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

    static private var networkEnabledKey = "networkEnabled"
    static var networkEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: networkEnabledKey) != nil {
                return UserDefaults.standard.bool(forKey: networkEnabledKey)
            }

            return networkEnabledDefault
        }
        set {
            if newValue != networkEnabled {
                UserDefaults.standard.set(newValue, forKey: networkEnabledKey)
                if newValue {
                    AppDelegate.main.syncDataWithBeamObject()
                }
            }
        }
    }

    static let topDomainsVersion = "0.1"

    static var topDomains: [String] = {
        let filePath = Bundle.main.path(forResource: "topdomains_v" + Self.topDomainsVersion, ofType: "txt")
        if let filePath = filePath, let result = try? String(contentsOfFile: filePath).components(separatedBy: "\n") {
            return result
        }
        return []
    }()

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

    static var stateRestorationEnabledDefault = false
    static private var stateRestorationEnabledKey = "stateRestorationEnabled"
    static var stateRestorationEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: stateRestorationEnabledKey) != nil {
                return UserDefaults.standard.bool(forKey: stateRestorationEnabledKey)
            }

            return stateRestorationEnabledDefault
        }
        set {
            if newValue != stateRestorationEnabled {
                UserDefaults.standard.set(newValue, forKey: stateRestorationEnabledKey)
            }
        }
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: publicHostnameKey)
        UserDefaults.standard.removeObject(forKey: apiHostnameKey)
        AccountManager.logout()
    }

    static private func value<T>(for key: String) -> T {
        guard let value = Bundle.main.infoDictionary?[key] as? T else {
            fatalError("Invalid or missing Info.plist key: \(key)")
        }
        return value
    }
}
