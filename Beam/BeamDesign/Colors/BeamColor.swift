//
//  BeamColor.swift
//  Beam
//
//  Created by Remi Santos on 06/04/2021.
//

import Foundation
import SwiftUI

indirect enum BeamColor {
    /** A light gray. */
    case AlphaGray
    /** Also known as Burple. A mix of blue and purple */
    case Beam
    /** Classic beam blue */
    case Bluetiful
    /** A soft green */
    case CharmedGreen
    /** A light gray. Lighter in dark mode */
    case Corduroy
    /** A light gray. Darker in dark mode */
    case LightStoneGray
    /** A white in light mode. A fake black in dark mode */
    case Mercury
    /** A fake black in dark mode. Unavailable in light mode */
    case Nero
    /** A dark gray in light mode. A fake whte in dark mode. Usually our main text color  */
    case Niobium
    /** A halloweenish orange */
    case Sanskrit
    /** A dangerous red */
    case Shiraz
    /** A smoke white in light mode. A mid gray in dark mode */
    case Tundora

    case Custom(named: String)
    case Combining(lightColor: BeamColor, darkColor: BeamColor)
    case From(color: NSColor)
}

extension BeamColor {
    var nsColor: NSColor {
        var colorName: String
        switch self {
        case .Custom(let named):
            colorName = named
        case .Combining(let lightColor, let darkColor):
            return NSColor(withLightColor: lightColor.nsColor, darkColor: darkColor.nsColor)
        case .From(let color):
            return color
        default:
            colorName = String(describing: self)
        }
        return NSColor.loadColor(named: colorName)
    }

    var swiftUI: SwiftUI.Color {
        SwiftUI.Color(self.nsColor)
    }

    var cgColor: CGColor {
        self.nsColor.cgColor
    }

    var hexColor: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        self.nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02x%02x%02x%02x", Int(red * 255), Int(green * 255), Int(blue * 255), Int(alpha * 255))
    }
}
