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
    static private(set) var env = ProcessInfo().arguments.contains(Configuration.uiTestModeLaunchArgument) ? .uiTest : Configuration.Env(rawValue: EnvironmentVariables.env) ?? .debug
    static private(set) var testAccountEmail = EnvironmentVariables.Account.testEmail
    static private(set) var testAccountPassword = EnvironmentVariables.Account.testPassword
    static private(set) var autoUpdate = EnvironmentVariables.autoUpdate
    /// Vinyl network recording is only used in unit tests (`ENV = test`).
    static var networkStubs: Bool { env == .test }
    static private(set) var updateFeedURL: String = Configuration.value(for: "SUFeedURL")

    static private(set) var uiTestModeLaunchArgument = "XCUITest"
    static private(set) var unitTestModeLaunchArgument = "test"

    static var buildSchemeName: String? {
        Bundle.main.infoDictionary?["SchemeName"] as? String
    }

    static private(set) var branchType = BranchType(rawValue: EnvironmentVariables.branchType)

    static private(set) var testPrivateKey = "j6tifPZTjUtGoz+1RJkO8dOMlu48MUUSlwACw/fCBw0="

    static let beamPrivacyPolicyLink = "https://beamapp.co/privacy"
    static let beamTermsConditionsLink = "https://beamapp.co/tos"
    static let beamOpenSourceRepoLink = "https://github.com/beamlegacy/beam"

    static var shouldDeleteEmptyDatabase = true

    /// When false, code paths that require general network access short-circuit (tests may toggle).
    static var networkEnabled = true

    /// Max number of beam objects for checksums query (tests only)
    static private(set) var checksumsChunkSize = 10_000

    static let topDomainsVersion = "0.1"

    static var topDomains: [String] = {
        let filePath = Bundle.main.path(forResource: "topdomains_v" + Self.topDomainsVersion, ofType: "txt")
        if let filePath = filePath, let result = try? String(contentsOfFile: filePath).components(separatedBy: "\n") {
            return result
        }
        return []
    }()

    /// Publish/embed HTTP client uses this base URL; remote Beam public API is not configured.
    static let publicAPIpublishServer = "about:blank"
    static let publicAPIembed = "about:blank"

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
        UserDefaults.standard.removeObject(forKey: stateRestorationEnabledKey)
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
        case uiTest
        case release
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
