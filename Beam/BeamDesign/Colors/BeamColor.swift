//
//  BeamColor.swift
//  Beam
//
//  Created by Remi Santos on 06/04/2021.
//

import Foundation
import SwiftUI

indirect enum BeamColor {
    // MARK: Primary
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
    /** AlphaGray with dark and light variation inverted */
    case InvertedAlphaGray
    /** Corduroy with dark and light variation inverted */
    case InvertedCorduroy
    /** LightStoneGray with dark and light variation inverted */
    case InvertedLightStoneGray
    /** Niobium with dark and light variation inverted */
    case InvertedNiobium
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

    // MARK: Secondary
    case Munsell

    // MARK: Helpers
    case Custom(named: String)
    case From(color: NSColor, alpha: CGFloat? = nil)

    #if DEBUG
    /// A random color, allowing easy debugging. **Only available in DEBUG builds**.
    case Random
    #endif

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
            appearance.fastIsDarkMode ? darkColor.nsColor.withAlphaComponent(darkAlpha) : lightColor.nsColor.withAlphaComponent(lightAlpha)
        })
    }
}

private extension NSAppearance {
    private static var isDarkModeCache = [NSAppearance.Name: Bool]()
    /// Performance helper. Use isDarkMode unless needed.
    /// For BeamColor.combining we need a fast way to repeatedly know if an appearance is dark,
    /// the origina NSAppearance.bestMatch() can be quite slow, so we're caching its answer.
    var fastIsDarkMode: Bool {
        let cached = Self.isDarkModeCache[self.name]
        if let cached = cached {
            return cached
        }
        let isDarkMode = self.isDarkMode
        Self.isDarkModeCache[self.name] = isDarkMode
        return isDarkMode
    }
}

extension BeamColor {

    func alpha(_ a: CGFloat) -> BeamColor {
        BeamColor.From(color: self.nsColor, alpha: a)
    }

    var nsColor: NSColor {
        let colorName: String
        switch self {
        case .Custom(let named):
            colorName = named
        case .From(let color, let alpha):
            if let alpha = alpha, alpha < 1 {
                return NSColor(name: nil) { _ in color.withAlphaComponent(alpha) }
            }
            return color
        #if DEBUG
        case .Random:
            return .random
        #endif
        default:
            colorName = String(describing: self)
        }
        let shouldBeCached = shouldBeCached
        let cacheKey = cacheKey
        if shouldBeCached, let cached = Self.nsColorCache[cacheKey] {
            return cached
        }
        let color = NSColor.loadColor(named: colorName)
        if shouldBeCached {
            Self.nsColorCache[cacheKey] = color
        }
        return color
    }

    func nsColor(for appearanceName: NSAppearance.Name) -> NSColor {
        var colorForAppearance = nsColor
        NSAppearance(named: appearanceName)?.performAsCurrentDrawingAppearance {
            if let flattenedColor = NSColor(cgColor: colorForAppearance.cgColor) {
                colorForAppearance = flattenedColor
            }
        }
        return colorForAppearance
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
        let shouldBeCached = shouldBeCached
        var cgCacheKey = ""
        if shouldBeCached {
            let currentAppearance = NSApp.effectiveAppearance.name.rawValue
            cgCacheKey = cacheKey + "-" + currentAppearance
            if let cached = Self.cgColorCache[cgCacheKey] {
                return cached
            }
        }
        var color: CGColor?
        NSAppearance.withAppAppearance {
            // Since we're inside a non-escaping closure, we will be able to return `color` outside of it.
            color = nsColor.cgColor
        }
        if shouldBeCached {
            Self.cgColorCache[cgCacheKey] = color
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

// MARK: - Performance
// See investigation: BE-4790
extension BeamColor {
    private var shouldBeCached: Bool {
        switch self {
        case .From: return false
        default: return true
        }
    }

    private var cacheKey: String {
        description
    }

    /// We're caching color accessor locally to avoid looking into asset catalog too much. [performance]
    private static var nsColorCache: [String: NSColor] = [:]
    /// We're caching color accessor locally to avoid converting colors too much. [performance]
    private static var cgColorCache: [String: CGColor] = [:]
}

extension BeamColor: CustomStringConvertible {

    // Using a custom description because String(describing: self) for an enum can be quite slow.
    var description: String {
        switch self {
        case .AlphaGray: return "AlphaGray"
        case .Beam: return "Beam"
        case .Bluetiful: return "Bluetiful"
        case .CharmedGreen: return "CharmedGreen"
        case .Corduroy: return "Corduroy"
        case .InvertedAlphaGray: return "InvertedAlphaGray"
        case .InvertedCorduroy: return "InvertedCorduroy"
        case .InvertedLightStoneGray: return "InvertedLightStoneGray"
        case .InvertedNiobium: return "InvertedNiobium"
        case .LightStoneGray: return "LightStoneGray"
        case .Mercury: return "Mercury"
        case .Nero: return "Nero"
        case .Niobium: return "Niobium"
        case .Sanskrit: return "Sanskrit"
        case .Shiraz: return "Shiraz"
        case .Tundora: return "Tundora"
        case .Munsell: return "Munsell"
        case .Custom(let named): return named
        case .From(let color, let alpha): return "From(\(color.componentsRGBAArray),a:\(alpha ?? 1)"
        #if DEBUG
        case .Random: return "Random"
        #endif
        }
    }
}

#if DEBUG
// MARK: - Debug helpers

extension NSColor {
    /// A random color, allowing easy debugging. **Only available in DEBUG builds**.
    static var random: NSColor {
        NSColor(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1.0)
    }
}

extension Color {
    /// A random color, allowing easy debugging. **Only available in DEBUG builds**.
    static var random: Color {
        Color(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), opacity: 1.0)
    }
}
#endif
