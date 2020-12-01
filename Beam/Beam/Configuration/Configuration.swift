import Foundation

// This file handles any configuration parameters
// Build configuration variables are defined in xcconfig files, feed Info.plist then accessed from here
// Runtime configuration variables are defined in Configuration.plist and accessed from here

struct Configuration {
    // Build configuration
    static private(set) var bundleIdentifier = ""
    static private(set) var sentryKey = ""
    static private(set) var sentryHostname = ""
    static private(set) var sentryProject = ""

    // Runtime configuration
    static private(set) var apiBaseUrl = ""
    static private(set) var publicHostname = ""

    static private(set) var environment: ConfigEnv = .dev

    enum ConfigEnv: String, CaseIterable {
        case prod, dev
    }

    static func apiBaseUrl(_ apiBaseurl: String) {
        self.apiBaseUrl = apiBaseurl
    }

    static func loadSavedEnvironment() {
        load(currentEnvironment)
    }

    static var EnvKey = "BeamEnvironment"
    static var currentEnvironment: ConfigEnv {
        let env = UserDefaults.standard.string(forKey: EnvKey)
        if let env = env, let enumEnv = ConfigEnv(rawValue: env) {
            return enumEnv
        }
        return .prod
    }

    //swiftlint:disable function_body_length
    static func load(_ newEnvironment: ConfigEnv = Configuration.environment) {
        UserDefaults.standard.set(newEnvironment.rawValue, forKey: EnvKey)
        environment = newEnvironment

        guard let path = Bundle.main.path(forResource: "Configuration", ofType: "plist"),
              let xml = FileManager.default.contents(atPath: path),
              let allConfig = (try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil)) as? [String: Any],
              let optionsConfig = allConfig["OPTIONS"] as? [String: String],
              let runtimeConfig = allConfig["RUNTIME-" + newEnvironment.rawValue] as? [String: String] else {
            fatalError("Missing config file")
        }

        sentryKey = optionsConfig["sentryKey"] ?? ""
        sentryProject = optionsConfig["sentryProject"] ?? ""
        sentryHostname = optionsConfig["sentryHostname"] ?? ""

        // Build
        bundleIdentifier = Configuration.value(for: "CFBundleIdentifier")

        // Runtime
        apiBaseUrl = runtimeConfig["apiBaseUrl"] ?? ""
        publicHostname = runtimeConfig["publicHostname"] ?? ""

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .environmentUpdated, object: nil)
        }
    }

    static private func value<T>(for key: String) -> T {
        guard let value = Bundle.main.infoDictionary?[key] as? T else {
            fatalError("Invalid or missing Info.plist key: \(key)")
        }
        return value
    }
}
