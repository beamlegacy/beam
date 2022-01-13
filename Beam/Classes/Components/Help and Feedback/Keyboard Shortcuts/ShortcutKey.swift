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

    // swiftlint:disable:next cyclomatic_complexity
    func symbol(withBackground: Bool = true) -> some View {
        let image: Image
        switch self {
        case .string(let str):
            image = characterImage(string: str)
        case .up:
            image = Image("shortcut-up_arrow")
        case .down:
            image = Image("shortcut-down_arrow")
        case .left:
            image = Image("shortcut-left_arrow")
        case .right:
            image = Image("shortcut-right_arrow")
        case .tab:
            image = Image("shortcut-tab_mac")
        case .enter:
            image = Image("shortcut-return")
        case .arobase:
            image = Image("shortcut-arobase")
        case .bracket:
            image = Image("shortcut-bracket")
        case .bracketReversed:
            image = Image("shortcut-bracket_reversed")
        case .doubleBracket:
            image = Image("shortcut-doublebracket")
        case .slash:
            image = Image("shortcut-slash")
        }
        return buildView(with: image, withBackground: withBackground)
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

    @ViewBuilder func buildView(with symbol: Image, withBackground: Bool) -> some View {
            symbol
                .renderingMode(.template)
                .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                .frame(minWidth: 12, minHeight: 18)
                .padding(.horizontal, 3)
                .background(withBackground ? RoundedRectangle(cornerRadius: 3)
                                .foregroundColor(BeamColor.Shortcut.background.swiftUI) : nil)
    }

    private func characterImage(string: String) -> Image {
        let attributedString = NSAttributedString(string: string.uppercased())
        let image = attributedString.image(foregroundColor: BeamColor.Corduroy.nsColor, font: BeamFont.medium(size: 12).nsFont)
        return Image(nsImage: image)
    }
}
