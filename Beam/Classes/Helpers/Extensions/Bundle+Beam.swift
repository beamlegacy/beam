//
//  Bundle+Beam.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 17/01/2022.
//

import Foundation

extension Bundle {
    var iconFileName: String? {
        guard let icon = infoDictionary?["CFBundleIconName"] as? String else {
            assertionFailure("Something was broken, we can't get the app icon from Info.plist")
            return nil
        }
        return icon
    }
}
