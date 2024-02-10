//
//  LottieView.swift
//  Beam
//
//  Created by Remi Santos on 20/09/2021.
//

import SwiftUI
import Lottie

extension LottieColor {
    init(color nscolor: NSColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nscolor.usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
    }
}

extension LottieView {
    func setColor(_ nsColor: NSColor) -> Self {
        configure { animationView in
            animationView.setColor(nsColor)
        }
    }
}
