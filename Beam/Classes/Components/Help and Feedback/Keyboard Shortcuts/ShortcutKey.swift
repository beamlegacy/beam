//
//  ShortcutKey.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 16/09/2021.
//

import SwiftUI

enum ShortcutKey: Hashable {
    case string(String)
    case up
    case down
    case left
    case right
    case tab
    case enter
    case arobase
    case bracket
    case bracketReversed
    case doubleBracket
    case slash

    var symbol: some View {
        switch self {
        case .string(let str):
            return buildView(with: characterImage(string: str))
        case .up:
            return buildView(with: Image("shortcut-up_arrow"))
        case .down:
            return buildView(with: Image("shortcut-down_arrow"))
        case .left:
            return buildView(with: Image("shortcut-left_arrow"))
        case .right:
            return buildView(with: Image("shortcut-right_arrow"))
        case .tab:
            return buildView(with: Image("shortcut-tab_mac"))
        case .enter:
            return buildView(with: Image("shortcut-return"))
        case .arobase:
            return buildView(with: Image("shortcut-arobase"))
        case .bracket:
            return buildView(with: Image("shortcut-bracket"))
        case .bracketReversed:
            return buildView(with: Image("shortcut-bracket_reversed"))
        case .doubleBracket:
            return buildView(with: Image("shortcut-doublebracket"))
        case .slash:
            return buildView(with: Image("shortcut-slash"))
        }
    }

    var buildHashValue: String {
        switch self {
        case .string(let char):
            return "character-\(char)"
        case .up:
            return "up"
        case .down:
            return "down"
        case .left:
            return "left"
        case .right:
            return "right"
        case .tab:
            return "tab"
        case .enter:
            return "enter"
        case .arobase:
            return "arobase"
        case .bracket:
            return "bracket"
        case .bracketReversed:
            return "bracketReversed"
        case .doubleBracket:
            return "doubleBracket"
        case .slash:
            return "slash"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(buildHashValue)
    }

    @ViewBuilder func buildView(with symbol: Image) -> some View {
            symbol
                .renderingMode(.template)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
                .frame(minWidth: 12, minHeight: 18)
                .padding(.horizontal, 3)
                .background(RoundedRectangle(cornerRadius: 3)
                                .foregroundColor(BeamColor.Mercury.swiftUI))
    }

    private func characterImage(string: String) -> Image {
        let attributedString = NSAttributedString(string: string.uppercased())
        let image = attributedString.image(foregroundColor: BeamColor.Corduroy.nsColor, font: BeamFont.medium(size: 12).nsFont)
        return Image(nsImage: image)
    }
}
