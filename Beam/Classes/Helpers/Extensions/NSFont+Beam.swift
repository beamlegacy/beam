//
//  NSFont+Beam.swift
//  Beam
//
//  Created by Remi Santos on 22/03/2021.
//

import Foundation
import SwiftUI

extension NSFont {
    static func beam_regular(ofSize: CGFloat) -> NSFont {
        return NSFont(name: "Inter", size: ofSize)!
    }
    static func beam_medium(ofSize: CGFloat) -> NSFont {
        return NSFont(name: "Inter-Medium", size: ofSize)!
    }
    static func beam_semibold(ofSize: CGFloat) -> NSFont {
        return NSFont(name: "Inter-SemiBold", size: ofSize)!
    }
    static func beam_bold(ofSize: CGFloat) -> NSFont {
        return NSFont(name: "Inter-Bold", size: ofSize)!
    }

    func toSwiftUIFont() -> SwiftUI.Font {
        return SwiftUI.Font.custom(self.fontName, size: self.pointSize)
    }
}
