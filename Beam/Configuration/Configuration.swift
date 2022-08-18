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

    /// Max number of beam objects for a checksums query
    static private(set) var checksumsChunkSize = 10_000

    // Runtime configuration
    // Set to "http://api.beam.lvh.me:5000" for running on a local API instance
    static private(set) var apiHostnameDefault = "https://api.prod.beamapp.co"
    static private(set) var restApiHostnameDefault = "https://api-rust.prod.beamapp.co"

    static private(set) var apiHostnameDefaultStaging = "https://api.staging.beamapp.co"
    static private(set) var restApiHostnameDefaultStaging = "https://api.staging.beamapp.co"

    static private(set) var apiHostnameDefaultDev = "https://api.beam.lvh.me"
    static private(set) var restApiHostnameDefaultDev = "https://api.beam.lvh.me"

    static private(set) var featureFlagURL = "https://s3.eu-west-3.amazonaws.com/downloads.beamapp.co/flags"

    static private(set) var beamObjectsPageSizeDefault = 1000

    static private(set) var beamObjectDataOnSeparateCallDefault = true

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

    static private(set) var beamObjectDataUploadOnSeparateCallDefault = true

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

    static private(set) var directUploadNIODefault =  Configuration.branchType == .develop
    static private var directUploadNIOKey = "directUploadNIO"
    // This is UPLOAD AND DOWNLOAD
    static var directUploadNIO: Bool {
        get {
            if UserDefaults.standard.object(forKey: directUploadNIOKey) != nil {
                return UserDefaults.standard.bool(forKey: directUploadNIOKey)
            }

            return directUploadNIODefault
        }
        set {
            if newValue != directUploadNIO {
                UserDefaults.standard.set(newValue, forKey: directUploadNIOKey)
            }
        }
    }

    static private(set) var directUploadAllObjectsDefault = Configuration.branchType == .develop
    static private var directUploadAllObjectsKey = "directUploadAllObjects"
    static var directUploadAllObjects: Bool {
        get {
            if UserDefaults.standard.object(forKey: directUploadAllObjectsKey) != nil {
                return UserDefaults.standard.bool(forKey: directUploadAllObjectsKey)
            }

            return directUploadAllObjectsDefault
        }
        set {
            if newValue != directUploadAllObjects {
                UserDefaults.standard.set(newValue, forKey: directUploadAllObjectsKey)
            }
        }
    }

    static private(set) var beamObjectOnRestDefault = true

    static private var beamObjectOnRestKey = "beamObjectOnRestKey"
    static var beamObjectOnRest: Bool {
        get {
            if UserDefaults.standard.object(forKey: beamObjectOnRestKey) != nil {
                return UserDefaults.standard.bool(forKey: beamObjectOnRestKey)
            }

            return beamObjectOnRestDefault
        }
        set {
            if newValue != beamObjectOnRest {
                UserDefaults.standard.set(newValue, forKey: beamObjectOnRestKey)
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
                BeamData.shared.currentAccount?.logout()
            }
        }
    }

    static private var beamObjectsApiHostnameKey = "beamObjectsApiHostname"
    static var beamObjectsApiHostname: String {
        get {
            UserDefaults.standard.string(forKey: beamObjectsApiHostnameKey) ?? apiHostname
        }
        set {
            if newValue != beamObjectsApiHostname {
                UserDefaults.standard.set(newValue, forKey: beamObjectsApiHostnameKey)
            }
        }
    }

    static private var restApiHostnameKey = "restApiHostname"
    static var restApiHostname: String {
        get {
            UserDefaults.standard.string(forKey: restApiHostnameKey) ?? restApiHostnameDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: restApiHostnameKey)
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
                    Task { @MainActor in
                        do {
                            _ = try await AppDelegate.main.syncDataWithBeamObject()
                        } catch {
                            Logger.shared.logError("Error while syncing data: \(error)", category: .document)
                        }
                    }
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

    static private var publicAPIpublishServerKey = "publicAPIpublishServerKey"
    static var publicAPIpublishServer: String {
        get {
            UserDefaults.standard.string(forKey: publicAPIpublishServerKey) ?? EnvironmentVariables.PublicAPI.publishServer
        }
        set {
            if newValue != publicAPIpublishServer && newValue != EnvironmentVariables.PublicAPI.publishServer {
                UserDefaults.standard.set(newValue, forKey: publicAPIpublishServerKey)
            }
        }
    }

    static private var publicAPIembedKey = "publicAPIembedKey"
    static var publicAPIembed: String {
        get {
            UserDefaults.standard.string(forKey: publicAPIembedKey) ?? EnvironmentVariables.PublicAPI.embed
        }
        set {
            if newValue != publicAPIembed && newValue != EnvironmentVariables.PublicAPI.embed {
                UserDefaults.standard.set(newValue, forKey: publicAPIembedKey)
                SupportedEmbedDomains.shared.clearCache()
                SupportedEmbedDomains.shared.updateDomainsSupportedByAPI()
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

    static private var beamObjectsPageSizeKey = "beamObjectsPageSize"
    static var beamObjectsPageSize: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: beamObjectsPageSizeKey)
            if value > 0 {
                return value
            } else {
                return beamObjectsPageSizeDefault
            }
        }
        set {
            if newValue != beamObjectsPageSize {
                UserDefaults.standard.set(newValue, forKey: beamObjectsPageSizeKey)
            }
        }
    }

    static func reset() {
        // URLs
        UserDefaults.standard.removeObject(forKey: publicAPIpublishServerKey)
        UserDefaults.standard.removeObject(forKey: publicAPIembedKey)
        UserDefaults.standard.removeObject(forKey: apiHostnameKey)
        UserDefaults.standard.removeObject(forKey: restApiHostnameKey)
        UserDefaults.standard.removeObject(forKey: beamObjectsApiHostnameKey)

        // Download & upload settings
        UserDefaults.standard.removeObject(forKey: beamObjectsPageSizeKey)
        UserDefaults.standard.removeObject(forKey: beamObjectDataOnSeparateCallKey)
        UserDefaults.standard.removeObject(forKey: beamObjectDataUploadOnSeparateCallKey)
        UserDefaults.standard.removeObject(forKey: beamObjectOnRestKey)
        UserDefaults.standard.removeObject(forKey: directUploadNIOKey)

        // Websocket
        UserDefaults.standard.removeObject(forKey: websocketEnabledKey)

        // Logout
        BeamData.shared.currentAccount?.logout()
    }

    static func setAPIEndPointsToStaging() {
        Self.apiHostname = apiHostnameDefaultStaging
        Self.restApiHostname = restApiHostnameDefaultStaging
        Self.publicAPIpublishServer = "https://staging-web-server.ew.r.appspot.com"
        Self.publicAPIembed = "https://staging-proxy-api.netlify.app/.netlify/functions/embed"
    }

    static func setAPIEndPointsToDevelopment() {
        Self.apiHostname = apiHostnameDefaultDev
        Self.restApiHostname = restApiHostnameDefaultDev
    }

    static private func value<T>(for key: String) -> T {
        guard let value = Bundle.main.infoDictionary?[key] as? T else {
            fatalError("Invalid or missing Info.plist key: \(key)")
        }
        return value
    }

    static func setChecksumsChunkSize(_ size: Int) {
        guard Configuration.env == .test else {
            fatalError("This parameter can only be set in test mode")
        }

        Self.checksumsChunkSize = size
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

extension Configuration {
    struct DailyUrlStats {
        static let daysToKeep = branchType == .develop ? 60 : 15
    }
}

extension Configuration {
    struct MockHttpServer {
        static let port = EnvironmentVariables.MockHttpServer.port
    }
}
