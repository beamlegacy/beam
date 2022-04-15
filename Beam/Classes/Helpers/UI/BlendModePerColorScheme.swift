//
//  BlendModePerColorScheme.swift
//  Beam
//
//  Created by Remi Santos on 24/11/2021.
//

import SwiftUI

private struct BlendModeMultiplyScreenModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var invert: Bool = false
    func body(content: Content) -> some View {
        content
            .blendMode(colorScheme == .dark ? darkMode : lightMode)
    }

    private var lightMode: BlendMode {
        invert ? .screen : .multiply
    }

    private var darkMode: BlendMode {
        invert ? .multiply : .screen
    }
}

extension View {
    /// Applies blendMode `.multiply` on light color scheme, and `.screen` on dark color scheme.
    ///
    /// This is our most common usage of blend modes in the app.
    func blendModeLightMultiplyDarkScreen(invert: Bool = false) -> some View {
        self.modifier(BlendModeMultiplyScreenModifier(invert: invert))
    }
}
