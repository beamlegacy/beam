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
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(buildHashValue)
    }

    @ViewBuilder func buildView(with symbol: Image) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .foregroundColor(BeamColor.Mercury.swiftUI)
            symbol
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
                .frame(width: 12, height: 12)
        }.frame(width: 18, height: 18)
    }

    private func characterImage(string: String) -> Image {
        let attributedString = NSAttributedString(string: string.uppercased())
        let image = attributedString.image(foregroundColor: BeamColor.Corduroy.nsColor, font: BeamFont.semibold(size: 14).nsFont)
        return Image(nsImage: image)
    }
}
