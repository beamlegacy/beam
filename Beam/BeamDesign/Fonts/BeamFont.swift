//
//  NSFont+Beam.swift
//  Beam
//
//  Created by Remi Santos on 22/03/2021.
//

import Foundation
import SwiftUI

enum BeamFont {
    case regular(size: CGFloat)
    case medium(size: CGFloat)
    case semibold(size: CGFloat)
    case bold(size: CGFloat)

    case regularItalic(size: CGFloat)
    case mediumItalic(size: CGFloat)
}

extension BeamFont {
    var nsFont: NSFont {
        switch self {
        case .regular(let size):
            return NSFont(name: "Inter", size: size)!
        case .medium(let size):
            return NSFont(name: "Inter-Medium", size: size)!
        case .semibold(let size):
            return NSFont(name: "Inter-SemiBold", size: size)!
        case .bold(let size):
            return NSFont(name: "Inter-Bold", size: size)!
        case .regularItalic(let size):
            return NSFont(name: "Inter-Italic", size: size)!
        case .mediumItalic(let size):
            return NSFont(name: "Inter-MediumItalic", size: size)!
        }
    }

    var swiftUI: SwiftUI.Font {
        let nsFont = self.nsFont
        return SwiftUI.Font.custom(nsFont.fontName, size: nsFont.pointSize)
    }
}
