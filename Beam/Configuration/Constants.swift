//
//  Constant.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 04/12/2020.
//

import Foundation
import AppKit

enum Constants {
    static let version = ProcessInfo.processInfo.operatingSystemVersion
    static var runningOnBigSur: Bool = {
        return version.majorVersion >= 11 || (version.majorVersion == 10 && version.minorVersion >= 16)
    }()

    /// Version of the system Safari, which ships the same WebKit as the one Beam runs on.
    /// Falls back to the Safari version bundled with the running macOS release.
    static let safariVersion: String = {
        if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari"),
           let safariVersion = Bundle(url: safariURL)?.infoDictionary?["CFBundleShortVersionString"] as? String,
           !safariVersion.isEmpty {
            return safariVersion
        }
        switch version.majorVersion {
        case 26...: return "\(version.majorVersion).0" // Safari adopted the OS version number with macOS 26
        case 15: return "18.0"
        case 14: return "17.0"
        case 13: return "16.0"
        default: return "15.0"
        }
    }()

    /// Appended by WebKit to its platform user agent ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)")
    static let SafariApplicationNameForUserAgent = "Version/\(safariVersion) Safari/605.1.15"
    static let SafariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) \(SafariApplicationNameForUserAgent)"
}
