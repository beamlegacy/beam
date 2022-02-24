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
    case From(color: NSColor, alpha: CGFloat? = nil)

    /**
     Creates a dynamic color with provided appearance color.

     Optional alpha parameters are applied inside the dynamic provider,
     because NSColor's `withAlphaComponent` could cause issue when switching between apperance.
     */
    static func combining(lightColor: BeamColor, lightAlpha: CGFloat = 1.0, darkColor: BeamColor, darkAlpha: CGFloat = 1.0) -> BeamColor {
        guard lightAlpha != 1.0 || darkAlpha != 1.0 else {
            return BeamColor.From(color: NSColor(withLightColor: lightColor.nsColor, darkColor: darkColor.nsColor))
        }
        return BeamColor.From(color: NSColor(name: nil) { appearance in
            appearance.isDarkMode ? darkColor.nsColor.withAlphaComponent(darkAlpha) : lightColor.nsColor.withAlphaComponent(lightAlpha)
        })
    }
}

extension BeamColor {

    func alpha(_ a: CGFloat) -> BeamColor {
        BeamColor.From(color: self.nsColor, alpha: a)
    }

    var nsColor: NSColor {
        var colorName: String
        switch self {
        case .Custom(let named):
            colorName = named
        case .From(let color, let alpha):
            if let alpha = alpha, alpha < 1 {
                return NSColor(name: nil) { _ in color.withAlphaComponent(alpha) }
            }
            return color
        default:
            colorName = String(describing: self)
        }
        return NSColor.loadColor(named: colorName)
    }

    /// Property originally returning the color value in the P3 Display color space. Preserved in case of needed
    /// rollback. [Read original discussion.](https://linear.app/beamapp/issue/BE-448/system-wide-switch-light-dark-mode-breaks-the-ui)
    ///
    /// staticColor computes an actual RGBA color from any symbolic color (for example created with NSColors(named: ...) ). It is important if you need to be able to compare colors as two NSColor(named: "yada") will actually be considered different (comparison will always fail). It serves a color in the Display P3 domain as it is the biggest domain on macOS (that I know of) which means it should encaspulate all colors without any risk of loss of precision. We need this for all the colors we use in the NSAttributedText produced by the editor as we need to be able to compare attributed text instances (and thus the colors  it uses).
    var staticColor: NSColor {
        nsColor
    }

    var swiftUI: SwiftUI.Color {
        SwiftUI.Color(self.nsColor)
    }

    var cgColor: CGColor {
        var color: CGColor?
        NSAppearance.withAppAppearance {
            // Since we're inside a non-escaping closure, we will be able to return `color` outside of it.
            color = nsColor.cgColor
        }
        return color ?? nsColor.cgColor
    }

    var hexColor: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        self.nsColor.usingColorSpace(.deviceRGB)?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02x%02x%02x%02x", Int(red * 255), Int(green * 255), Int(blue * 255), Int(alpha * 255))
    }
}
