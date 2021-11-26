//
//  BlendModePerColorScheme.swift
//  Beam
//
//  Created by Remi Santos on 24/11/2021.
//

import SwiftUI

private struct BlendModeMultiplyScreenModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    func body(content: Content) -> some View {
        content
            .blendMode(colorScheme == .dark ? .screen : .multiply)
    }
}

extension View {
    /// Applies blendMode `.multiply` on light color scheme, and `.screen` on dark color scheme.
    ///
    /// This is our most common usage of blend modes in the app.
    func blendModeLightMultiplyDarkScreen() -> some View {
        self.modifier(BlendModeMultiplyScreenModifier())
    }
}
