//
//  NSFont+Beam.swift
//  Beam
//
//  Created by Remi Santos on 22/03/2021.
//

import Foundation
import SwiftUI

enum BeamFont {
    case light(size: CGFloat)
    case regular(size: CGFloat)
    case medium(size: CGFloat)
    case semibold(size: CGFloat)
    case bold(size: CGFloat)

    case lightItalic(size: CGFloat)
    case regularItalic(size: CGFloat)
    case mediumItalic(size: CGFloat)
    case semiboldItalic(size: CGFloat)
    case boldItalic(size: CGFloat)
}

extension BeamFont {
    private func defaultFont(ofSize: CGFloat) -> NSFont {
        .systemFont(ofSize: ofSize)
    }

    var nsFont: NSFont {
        switch self {
        case .light(size: let size):
            return NSFont(name: "Inter-Light", size: size) ?? defaultFont(ofSize: size)
        case .regular(let size):
            return NSFont(name: "Inter-Regular", size: size) ?? defaultFont(ofSize: size)
        case .medium(let size):
            return NSFont(name: "Inter-Medium", size: size) ?? defaultFont(ofSize: size)
        case .semibold(let size):
            return NSFont(name: "Inter-SemiBold", size: size) ?? defaultFont(ofSize: size)
        case .bold(let size):
            return NSFont(name: "Inter-Bold", size: size) ?? defaultFont(ofSize: size)
        case .lightItalic(size: let size):
            return NSFont(name: "Inter-LightItalic", size: size) ?? defaultFont(ofSize: size)
        case .regularItalic(let size):
            return NSFont(name: "Inter-Italic", size: size) ?? defaultFont(ofSize: size)
        case .mediumItalic(let size):
            return NSFont(name: "Inter-MediumItalic", size: size) ?? defaultFont(ofSize: size)
        case .semiboldItalic(size: let size):
            return NSFont(name: "Inter-SemiBoldItalic", size: size) ?? defaultFont(ofSize: size)
        case .boldItalic(size: let size):
            return NSFont(name: "Inter-BoldItalic", size: size) ?? defaultFont(ofSize: size)

        }
    }

    var swiftUI: SwiftUI.Font {
        let nsFont = self.nsFont
        return SwiftUI.Font.custom(nsFont.fontName, size: nsFont.pointSize)
    }
}
