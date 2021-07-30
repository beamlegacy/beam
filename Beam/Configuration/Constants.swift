//
//  Constant.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 04/12/2020.
//

import Foundation

enum Constants {

    static var runningOnBigSur: Bool = {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion >= 11 || (version.majorVersion == 10 && version.minorVersion >= 16)
    }()

    static var SafariUserAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15"
}
