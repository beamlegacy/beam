//
//  TabGroupingColor.swift
//  Beam
//
//  Created by Remi Santos on 23/05/2022.
//

import SwiftUI

/// Describe the color of a Tab Group.
///
/// A group color can be either
/// - one of our designed colors, in that case `TabGroupingColor.designColor` will have a value
/// - a random color generated with only a hue value, in that case `TabGroupingColor.randomColorHueTint` will have a value (and not designColor)
struct TabGroupingColor: Identifiable, Hashable {

    enum DesignColor: String, CaseIterable, Identifiable {
        case red, yellow, green, cyan, blue, pink, purple, birgit, gray

        var id: String {
            rawValue
        }
        var color: BeamColor {
            guard let c = Self.colors[self] else {
                fatalError("Missing color for DesignColor value for '\(self)'")
            }
            return c
        }
        var textColor: BeamColor {
            guard let c = Self.textColors[self] else {
                fatalError("Missing text color for DesignColor value for '\(self)'")
            }
            return c
        }

        static var colors: [DesignColor: BeamColor] = [
            .red: .TabGrouping.red,
            .yellow: .TabGrouping.yellow,
            .green: .TabGrouping.green,
            .cyan: .TabGrouping.cyan,
            .blue: .TabGrouping.blue,
            .pink: .TabGrouping.pink,
            .purple: .TabGrouping.purple,
            .birgit: .TabGrouping.birgit,
            .gray: .TabGrouping.gray
        ]
        static var textColors: [DesignColor: BeamColor] = [
            .red: .TabGrouping.redText,
            .yellow: .TabGrouping.yellowText,
            .green: .TabGrouping.greenText,
            .cyan: .TabGrouping.cyanText,
            .blue: .TabGrouping.blueText,
            .pink: .TabGrouping.pinkText,
            .purple: .TabGrouping.purpleText,
            .birgit: .TabGrouping.birgitText,
            .gray: .TabGrouping.grayText
        ]
    }

    static func == (lhs: TabGroupingColor, rhs: TabGroupingColor) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var id: String {
        if let designColor = designColor {
            return "designColor[\(designColor.rawValue)]"
        } else if let hueTint = randomColorHueTint {
            return "randomColor[hue:\(hueTint)]"
        }
        return "unknown"
    }

    private(set) var designColor: DesignColor?
    private(set) var randomColorHueTint: Double?

    var mainColor: BeamColor?
    var textColor: BeamColor?

    internal init(designColor: DesignColor? = nil, randomColorHueTint: Double? = nil) {
        let designColor = designColor ?? (randomColorHueTint == nil ? DesignColor.allCases.first : nil)
        self.designColor = designColor
        self.randomColorHueTint = randomColorHueTint
        if let designColor = designColor {
            mainColor = designColor.color
            textColor = designColor.textColor
        } else if let hue = randomColorHueTint {
            let light = BeamColor.From(color: NSColor(hue: hue, saturation: 0.58, brightness: 0.96, alpha: 1))
            let dark = BeamColor.From(color: NSColor(hue: hue, saturation: 0.58, brightness: 0.86, alpha: 1))
            mainColor = BeamColor.combining(lightColor: light, darkColor: dark)
            let lightText = BeamColor.From(color: .white)
            let darkText = BeamColor.From(color: NSColor(hue: hue, saturation: 0.5, brightness: 0.36, alpha: 1))
            textColor = BeamColor.combining(lightColor: lightText, darkColor: darkText)
        }
    }

}

final class TabGroupingColorGenerator {
    var hueGenerator = DistributedRandomGenerator(range: 0.0..<1.0)

    private var usedColors = Set<TabGroupingColor>()

    func generateNewColor() -> TabGroupingColor {
        let availableColorNames = TabGroupingColor.DesignColor.allCases.filter { c in
            !usedColors.contains(where: { $0.designColor == c })
        }
        guard !availableColorNames.isEmpty, let designColor = availableColorNames.randomElement() else {
            let hue = hueGenerator.generate()
            hueGenerator.taken.append(hue)
            let color = TabGroupingColor(randomColorHueTint: hue)
            usedColors.insert(color)
            return color
        }
        let color = TabGroupingColor(designColor: designColor)
        usedColors.insert(color)
        return color
    }

    func updateUsedColor(_ colors: [TabGroupingColor]) {
        usedColors = Set(colors)
        hueGenerator.taken = Array(Set(colors.compactMap { $0.randomColorHueTint }))
    }
}
