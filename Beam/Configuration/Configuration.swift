import Foundation
import BeamCore

struct Configuration {
    // Build configuration
    static private(set) var bundleIdentifier: String = Configuration.value(for: "CFBundleIdentifier")
    static private(set) var sentryKey = EnvironmentVariables.Sentry.key
    static private(set) var sentryHostname = "o477543.ingest.sentry.io"
    static private(set) var sentryProject = "5518785"
    static private(set) var env = EnvironmentVariables.env
    static private(set) var testAccountEmail = "fabien+test@beamapp.co"
    static private(set) var testAccountPassword = EnvironmentVariables.Account.testPassword
    static private(set) var autoUpdate = EnvironmentVariables.autoUpdate
    static private(set) var networkStubs = EnvironmentVariables.networkStubs
    static private(set) var updateFeedURL: String = Configuration.value(for: "SUFeedURL")
    static private(set) var sentryEnabled = EnvironmentVariables.sentryEnabled
    static var networkEnabled = EnvironmentVariables.networkEnabled
    static var encryptionEnabledDefault = EnvironmentVariables.encryptionEnabled
    static var pnsStatus = EnvironmentVariables.pnsStatus

    static private(set) var sentryDsn = "https://\(sentryKey)@\(sentryHostname)/\(sentryProject)"

    // Runtime configuration
    static private(set) var apiHostnameDefault = "https://api.beamapp.co"
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

    static private var encryptionEnabledKey = "encryptionEnabled"
    static var encryptionEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: encryptionEnabledKey) != nil {
                return UserDefaults.standard.bool(forKey: encryptionEnabledKey)
            }

            return encryptionEnabledDefault
        }
        set {
            if newValue != encryptionEnabled {
                UserDefaults.standard.set(newValue, forKey: encryptionEnabledKey)
            }
        }
    }

    static private var beamObjectAPIEnabledKey = "beamObjectAPIEnabled"
    static var beamObjectAPIEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: beamObjectAPIEnabledKey) != nil {
                return UserDefaults.standard.bool(forKey: beamObjectAPIEnabledKey)
            }

            return EnvironmentVariables.beamObjectAPIEnabled
        }
        set {
            if newValue != beamObjectAPIEnabled {
                UserDefaults.standard.set(newValue, forKey: beamObjectAPIEnabledKey)
            }
        }
    }

    static private var databaseIdKey = "databaseId"
    static var databaseId: String? {
        get {
            UserDefaults.standard.string(forKey: databaseIdKey)
        }
        set {
            if newValue != databaseId {
                UserDefaults.standard.set(newValue, forKey: databaseIdKey)
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

    static var browsingSessionCollectionIsOnDefault = true
    static var browsingSessionCollectionIsOn: Bool {
        get {
            if UserDefaults.standard.object(forKey: "browsingSessionCollectionIsOn") != nil {
                return UserDefaults.standard.bool(forKey: "browsingSessionCollectionIsOn")
            }

            return browsingSessionCollectionIsOnDefault
        }
        set {
            if newValue != browsingSessionCollectionIsOn {
                UserDefaults.standard.set(newValue, forKey: "browsingSessionCollectionIsOn")
            }
        }
    }
}
