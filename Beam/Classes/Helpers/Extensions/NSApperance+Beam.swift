//
//  NSApperance+Beam.swift
//  Beam
//
//  Created by Remi Santos on 11/03/2021.
//

import Foundation

extension NSAppearance {
    public var isDarkMode: Bool {
        let isDarkMode: Bool

        if self.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            isDarkMode = true
        } else {
            isDarkMode = false
        }
        return isDarkMode
    }

    static func withAppAppearance(_ block: () -> Void) {
        if #available(macOS 11.0, *) {
            NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
                block()
            }
        } else {
            let previousAppearance = NSAppearance.current
            NSAppearance.current = NSApp.effectiveAppearance
            defer {
                NSAppearance.current = previousAppearance
            }
            block()
        }
    }
}
