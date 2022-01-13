//
//  ShortcutModifier.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 16/09/2021.
//

import SwiftUI

enum ShortcutModifier: Hashable {
    case option
    case command
    case shift
    case control

    func symbol(withBackground: Bool = true) -> some View {
        let image: Image
        switch self {
        case .option:
            image = Image("shortcut-option")
        case .command:
            image = Image("shortcut-cmd")
        case .shift:
            image = Image("shortcut-shift")
        case .control:
            image = Image("shortcut-control")
        }
        return buildView(with: image, withBackground: withBackground)
    }

    @ViewBuilder func buildView(with symbol: Image, withBackground: Bool) -> some View {
        symbol
            .renderingMode(.template)
            .foregroundColor(BeamColor.LightStoneGray.swiftUI)
            .padding(3)
            .background(withBackground ? RoundedRectangle(cornerRadius: 3)
                            .foregroundColor(BeamColor.Shortcut.background.swiftUI) : nil)
    }
}
