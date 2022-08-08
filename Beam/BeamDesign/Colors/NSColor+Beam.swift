//
//  NSColor+Beam.swift
//  Beam
//
//  Created by Remi Santos on 07/04/2021.
//

import Foundation
import SwiftUI

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

// MARK: Color blending
extension NSColor {
    func add(_ overlay: NSColor) -> NSColor {
        var bgR: CGFloat = 0
        var bgG: CGFloat = 0
        var bgB: CGFloat = 0
        var bgA: CGFloat = 0

        var fgR: CGFloat = 0
        var fgG: CGFloat = 0
        var fgB: CGFloat = 0
        var fgA: CGFloat = 0

        self.usingColorSpace(.deviceRGB)?.getRed(&bgR, green: &bgG, blue: &bgB, alpha: &bgA)
        overlay.usingColorSpace(.deviceRGB)?.getRed(&fgR, green: &fgG, blue: &fgB, alpha: &fgA)

        let r = fgA * fgR + (1 - fgA) * bgR
        let g = fgA * fgG + (1 - fgA) * bgG
        let b = fgA * fgB + (1 - fgA) * bgB

        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    static func + (lhs: NSColor, rhs: NSColor) -> NSColor {
        return lhs.add(rhs)
    }

    var componentsRGBA: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        guard let color = self.usingColorSpace(.deviceRGB) else {
            fatalError()
        }
        return (r: color.redComponent, g: color.greenComponent, b: color.blueComponent, a: color.alphaComponent)
    }

    var componentsRGBAArray: [CGFloat] {
        let (r, g, b, a) = self.componentsRGBA
        return [r, g, b, a]
    }
}
