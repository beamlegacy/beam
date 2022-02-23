import Foundation
import BeamCore

enum BranchType: String {
    case develop
    case beta
    case publicRelease = "public"
}

struct Configuration {
    // Build configuration
    static private(set) var bundleIdentifier: String = Configuration.value(for: "CFBundleIdentifier")
    static private(set) var env = Configuration.Env(rawValue: EnvironmentVariables.env) ?? .debug
    static private(set) var testAccountEmail = EnvironmentVariables.Account.testEmail
    static private(set) var testAccountPassword = EnvironmentVariables.Account.testPassword
    static private(set) var autoUpdate = EnvironmentVariables.autoUpdate
    static private(set) var networkStubs = EnvironmentVariables.networkStubs
    static private(set) var updateFeedURL: String = Configuration.value(for: "SUFeedURL")
    static private(set) var sentryEnabled = EnvironmentVariables.sentryEnabled
    static private(set) var networkEnabledDefault = EnvironmentVariables.networkEnabled
    static private var websocketEnabledDefault = true
    static private(set) var topDomainDBMaxSize = 10000

    static private(set) var uiTestModeLaunchArgument = "XCUITest"
    static private(set) var unitTestModeLaunchArgument = "test"
    static private(set) var browsingTreeApiSyncEnabled = EnvironmentVariables.BrowsingTree.apiSyncEnabled

    static var buildSchemeName: String? {
        Bundle.main.infoDictionary?["SchemeName"] as? String
    }

    static private(set) var branchType = BranchType(rawValue: EnvironmentVariables.branchType)

    static private(set) var testPrivateKey = "j6tifPZTjUtGoz+1RJkO8dOMlu48MUUSlwACw/fCBw0="

    static let beamPrivacyPolicyLink = "https://beamapp.co/privacy"
    static let beamTermsConditionsLink = "https://beamapp.co/tos"

    static var shouldDeleteEmptyDatabase = true

    // Runtime configuration
    // Set to "http://api.beam.lvh.me:5000" for running on a local API instance
    static private(set) var apiHostnameDefault = "https://api.beamapp.co" // "http://api.beam.lvh.me"
    static private(set) var publicHostnameDefault = "https://app.beamapp.co"

    static private(set) var beamObjectDataOnSeparateCallDefault = false

    static var beamObjectDirectCall: Bool {
        get { fatalError("Don't use this") }

        set {
            beamObjectDataOnSeparateCall = newValue
            beamObjectDataUploadOnSeparateCall = newValue
        }
    }

    static private var beamObjectDataOnSeparateCallKey = "beamObjectDataOnSeparateCall"
    static var beamObjectDataOnSeparateCall: Bool {
        get {
            if UserDefaults.standard.object(forKey: beamObjectDataOnSeparateCallKey) != nil {
                return UserDefaults.standard.bool(forKey: beamObjectDataOnSeparateCallKey)
            }

            return beamObjectDataOnSeparateCallDefault
        }
        set {
            if newValue != beamObjectDataOnSeparateCall {
                UserDefaults.standard.set(newValue, forKey: beamObjectDataOnSeparateCallKey)
            }
        }
    }

    //swiftlint:disable:next identifier_name
    static private(set) var beamObjectDataUploadOnSeparateCallDefault = false

    static private var beamObjectDataUploadOnSeparateCallKey = "beamObjectDataUploadOnSeparateCall"
    static var beamObjectDataUploadOnSeparateCall: Bool {
        get {
            if UserDefaults.standard.object(forKey: beamObjectDataUploadOnSeparateCallKey) != nil {
                return UserDefaults.standard.bool(forKey: beamObjectDataUploadOnSeparateCallKey)
            }

            return beamObjectDataUploadOnSeparateCallDefault
        }
        set {
            if newValue != beamObjectDataUploadOnSeparateCall {
                UserDefaults.standard.set(newValue, forKey: beamObjectDataUploadOnSeparateCallKey)
            }
        }
    }

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

    static private var websocketEnabledKey = "websocketEnabled"
    static var websocketEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: websocketEnabledKey) != nil {
                return UserDefaults.standard.bool(forKey: websocketEnabledKey)
            }

            return websocketEnabledDefault
        }
        set {
            if newValue != websocketEnabled {
                UserDefaults.standard.set(newValue, forKey: websocketEnabledKey)
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

extension Configuration {
    enum Env: String {
        case debug
        case test
        case release
    }
}

extension Configuration {
    struct Sentry {
        static let key = EnvironmentVariables.Sentry.key
        static let hostname = "o477543.ingest.sentry.io"
        static let projectID = "5518785"
        static let DSN = "https://\(key)@\(hostname)/\(projectID)"
    }
}

extension Configuration {
    struct Firebase {
        static let clientID = env == .release ? EnvironmentVariables.Firebase.clientID : EnvironmentVariables.Firebase.clientIDDev
        static let apiKey =  env == .release ? EnvironmentVariables.Firebase.apiKey : EnvironmentVariables.Firebase.apiKeyDev
        static let googleAppID =  env == .release ? EnvironmentVariables.Firebase.googleAppID : EnvironmentVariables.Firebase.googleAppIDDev
        static let projectID =  env == .release ? EnvironmentVariables.Firebase.projectID : EnvironmentVariables.Firebase.projectIDDev
        static let reversedClientID = clientID.split(separator: ".").reversed().joined(separator: ".")

        static let plistDictionary: [String: Any] = [
            "API_KEY": apiKey,
            "BUNDLE_ID": bundleIdentifier,
            "CLIENT_ID": clientID,
            "GOOGLE_APP_ID": googleAppID,
            "PLIST_VERSION": "1",
            "PROJECT_ID": projectID,
            "REVERSED_CLIENT_ID": reversedClientID,
            "STORAGE_BUCKET": "\(projectID).appspot.com",
            "IS_ADS_ENABLED": 0,
            "IS_ANALYTICS_ENABLED": 1,
            "IS_APPINVITE_ENABLED": 0,
            "IS_GCM_ENABLED": 0,
            "IS_SIGNIN_ENABLED": 1
        ]
    }
}
