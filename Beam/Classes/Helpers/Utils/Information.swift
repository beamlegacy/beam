import Foundation

struct Information {
    static var appVersionAndBuild: String {
        guard let version = appVersion, let build = appBuild else { return "no version" }
        return version + " (" + build + ")"
    }

    static var appName: String? {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String
    }

    static var appVersion: String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    static var appBuild: String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    static var osVersion: String {
        let operatingSystem = ProcessInfo().operatingSystemVersion
        return "\(operatingSystem.majorVersion).\(operatingSystem.minorVersion).\(operatingSystem.patchVersion)"
    }
}
