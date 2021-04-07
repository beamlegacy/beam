//
//  NSColor+Beam.swift
//  Beam
//
//  Created by Remi Santos on 07/04/2021.
//

import Foundation

extension NSColor {

    internal convenience init(withLightColor lightColor: NSColor, darkColor: NSColor) {
        self.init(name: nil) { (appearance) -> NSColor in
            return appearance.isDarkMode ? darkColor : lightColor
        }
    }

    internal class func loadColor(named: String) -> NSColor {
        guard let color = NSColor(named: named) else {
            fatalError("Couln't find \(named) color.")
        }

        return color
    }
}
