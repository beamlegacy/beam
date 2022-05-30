//
//  TabGroupingColor.swift
//  Beam
//
//  Created by Remi Santos on 23/05/2022.
//

import SwiftUI

struct TabGroupingColor: Identifiable, Hashable {

    static let userColors: [BeamColor] = [
        .TabGrouping.red, .TabGrouping.yellow, .TabGrouping.green, .TabGrouping.cyan, .TabGrouping.blue,
        .TabGrouping.pink, .TabGrouping.purple, .TabGrouping.birgit, .TabGrouping.gray
    ]
    static let userTextColors: [BeamColor] = [
        .TabGrouping.redText, .TabGrouping.yellowText, .TabGrouping.greenText, .TabGrouping.cyanText, .TabGrouping.blueText,
        .TabGrouping.pinkText, .TabGrouping.purpleText, .TabGrouping.birgitText, .TabGrouping.grayText
    ]

    static func == (lhs: TabGroupingColor, rhs: TabGroupingColor) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var id: String {
        if let userColorIndex = userColorIndex {
            return "userColor[\(userColorIndex)]"
        } else if let hueTint = hueTint {
            return "hueTint[\(hueTint)]"
        }
        return "unknown"
    }

    private(set) var hueTint: Double?
    private(set) var userColorIndex: Int?
    private var userColor: BeamColor?
    private var userTextColor: BeamColor?

    internal init(userColorIndex: Int? = nil, hueTint: Double? = nil) {
        self.userColorIndex = userColorIndex
        self.hueTint = hueTint
        if let userColorIndex = userColorIndex {
            userColor = Self.userColors[userColorIndex]
            userTextColor = Self.userTextColors[userColorIndex]
        }
    }

    func mainColor(isDarkMode: Bool) -> SwiftUI.Color {
        if let userColor = userColor {
            return userColor.swiftUI
        } else if let hueTint = hueTint {
            return Color(hue: hueTint, saturation: 0.58, brightness: isDarkMode ? 0.86 : 0.96)
        }
        return .clear
    }

    func textColor(isDarkMode: Bool) -> SwiftUI.Color {
        if let userTextColor = userTextColor {
            return userTextColor.swiftUI
        } else if let hueTint = hueTint {
            if !isDarkMode {
                return .white
            }
            return Color(hue: hueTint, saturation: 0.5, brightness: 0.36)
        }
        return .clear
    }
}

final class TabGroupingColorGenerator {
    var hueGenerator = DistributedRandomGenerator(range: 0.0..<1.0)

    private var usedColors = Set<TabGroupingColor>()

    func generateNewColor() -> TabGroupingColor {
        let availableUserColorIndexes = Array(0..<TabGroupingColor.userColors.count).filter { idx in
            !usedColors.contains(where: { $0.userColorIndex == idx })
        }
        guard !availableUserColorIndexes.isEmpty, let userColorIndex = availableUserColorIndexes.randomElement() else {
            let hue = hueGenerator.generate()
            hueGenerator.taken.append(hue)
            let color = TabGroupingColor(hueTint: hue)
            usedColors.insert(color)
            return color
        }
        let color = TabGroupingColor(userColorIndex: userColorIndex)
        usedColors.insert(color)
        return color
    }

    func updateUsedColor(_ colors: [TabGroupingColor]) {
        usedColors = Set(colors)
        hueGenerator.taken = Array(Set(colors.compactMap { $0.hueTint }))
    }
}
