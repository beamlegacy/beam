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
    var textSelectionColor: BeamColor?

    internal init(designColor: DesignColor? = nil, randomColorHueTint: Double? = nil) {
        let designColor = designColor ?? (randomColorHueTint == nil ? DesignColor.allCases.first : nil)
        self.designColor = designColor
        self.randomColorHueTint = randomColorHueTint
        if let designColor = designColor {
            mainColor = designColor.color
            var hue: CGFloat = 0
            designColor.color.nsColor.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
            textColor = BeamColor.From(color: NSColor(hue: hue, saturation: 1, brightness: 0.18, alpha: 1))
        } else if let hue = randomColorHueTint {
            let light = BeamColor.From(color: NSColor(hue: hue, saturation: 0.63, brightness: 0.99, alpha: 1))
            let dark = BeamColor.From(color: NSColor(hue: hue, saturation: 0.63, brightness: 0.85, alpha: 1))
            mainColor = BeamColor.combining(lightColor: light, darkColor: dark)
            textColor = BeamColor.From(color: NSColor(hue: hue, saturation: 1, brightness: 0.18, alpha: 1))
        }
        textSelectionColor = mainColor?.alpha(0.14)
    }

    struct CodableColor: Codable {
        var colorName: String?
        var hueTint: Double?
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
