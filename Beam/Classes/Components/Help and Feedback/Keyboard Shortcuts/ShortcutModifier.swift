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

    var symbol: some View {
        switch self {
        case .option:
            return buildView(with: Image("shortcut-option"))
        case .command:
            return buildView(with: Image("shortcut-cmd"))
        case .shift:
            return buildView(with: Image("shortcut-shift"))
        case .control:
            return buildView(with: Image("shortcut-control"))
        }
    }

    @ViewBuilder func buildView(with symbol: Image) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .foregroundColor(BeamColor.Mercury.swiftUI)
            symbol
                .resizable()
                .renderingMode(.template)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
                .frame(width: 11, height: 11)
        }.frame(width: 18, height: 18)
    }
}
