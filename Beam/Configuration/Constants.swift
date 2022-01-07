//
//  Constant.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 04/12/2020.
//

import Foundation

enum Constants {
    static let version = ProcessInfo.processInfo.operatingSystemVersion
    static var runningOnBigSur: Bool = {
        return version.majorVersion >= 11 || (version.majorVersion == 10 && version.minorVersion >= 16)
    }()

    static var SafariUserAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(version) Safari/605.1.15"
}
