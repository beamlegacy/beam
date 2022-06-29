//
//  BlendModePerColorScheme.swift
//  Beam
//
//  Created by Remi Santos on 24/11/2021.
//

import SwiftUI

private struct BlendModeMultiplyScreenModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var lightBlendingMode: BlendMode
    var darkBlendingMode: BlendMode

    var invert: Bool = false
    func body(content: Content) -> some View {
        content
            .blendMode(colorScheme == .dark ? darkBlendingMode : lightBlendingMode)
    }
}

extension View {
    /// Applies blendMode `.multiply` on light color scheme, and `.screen` on dark color scheme.
    ///
    /// This is our most common usage of blend modes in the app.
    func blendModeLightMultiplyDarkScreen(invert: Bool = false) -> some View {
        self.modifier(BlendModeMultiplyScreenModifier(lightBlendingMode: invert ? .screen : .multiply,
                                                      darkBlendingMode: invert ? .multiply : .screen))
    }

    /// Applies a different blend mode depending on the color scheme
    func blendMode(forLightScheme: BlendMode, forDarkScheme: BlendMode) -> some View {
        self.modifier(BlendModeMultiplyScreenModifier(lightBlendingMode: forLightScheme,
                                                      darkBlendingMode: forDarkScheme))
    }
}
