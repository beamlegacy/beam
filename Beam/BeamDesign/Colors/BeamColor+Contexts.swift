//
//  BeamColor+Contexts.swift
//  Beam
//
//  Created by Remi Santos on 07/04/2021.
//

import Foundation

extension BeamColor {

    enum Generic {
        static let background = BeamColor.Custom(named: "WindowBackgroundColor")
        static let text = BeamColor.Niobium
        static let subtitle = BeamColor.LightStoneGray
        static let placeholder = BeamColor.AlphaGray
        static let transparent = BeamColor.Custom(named: "Transparent")
        static let separator = BeamColor.Mercury
    }

    enum ContextMenu {
        static let hover = BeamColor.Mercury
    }
}

extension BeamColor {
    enum Editor {
        static let icon = BeamColor.LightStoneGray
        static let bullet = BeamColor.AlphaGray
        static let chevron = BeamColor.AlphaGray
        static let searchNormal = BeamColor.Custom(named: "EditorSearchNormal")
        static let searchHover = BeamColor.Bluetiful
        static let searchClicked = BeamColor.Custom(named: "EditorSearchClicked")
        static let bidirectionalLink = BeamColor.Beam
        static let bidirectionalLinkBackground = BeamColor.From(color: BeamColor.Beam.nsColor.withAlphaComponent(0.08))
        static let bidirectionalLinkHighlightedBackground = BeamColor.From(color: BeamColor.Beam.nsColor.withAlphaComponent(0.24))
        static let bidirectionalUnderline = BeamColor.From(color: BeamColor.Beam.nsColor.withAlphaComponent(0.25))
        static let control = BeamColor.Custom(named: "EditorControlColor")
        static let link = BeamColor.Niobium
        static let linkActive = BeamColor.Bluetiful
        static let linkActiveBackground = BeamColor.From(color: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.1))
        static let linkActiveHighlightedBackground = BeamColor.From(color: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.24))
        static var linkDecoration = BeamColor.Combining(lightColor: BeamColor.AlphaGray, darkColor: BeamColor.LightStoneGray)
        static let syntax = BeamColor.Custom(named: "EditorSyntaxColor")
        static let indentBackground = BeamColor.Mercury
        static let underlineAndStrikethrough = BeamColor.Niobium
    }
}

extension BeamColor {
    enum Card {
        static let optionIcon = BeamColor.LightStoneGray
    }
}

extension BeamColor {
    enum LinkedSection {
        static let sectionTitle = BeamColor.AlphaGray
        static let actionButtonBackgroundHover = BeamColor.Mercury
        static let actionButtonHover = BeamColor.Niobium
        static let actionButton = BeamColor.AlphaGray
        static let chevronIcon = BeamColor.LightStoneGray
        static let breadcrumb = BeamColor.LightStoneGray
        static let breadcrumbHover = BeamColor.Niobium
        static let separator = BeamColor.Nero
        static let title = BeamColor.Beam
        static let container = BeamColor.Custom(named: "EditorLinkContainer")
    }
}

extension BeamColor {
    enum DebugSection {
        static let sectionTitle = BeamColor.AlphaGray
        static let separator = BeamColor.Nero
    }
}

extension BeamColor {
    enum Formatter {
        static let background = BeamColor.From(color: NSColor(withLightColor: NSColor.white.withAlphaComponent(0.98), darkColor: BeamColor.Nero.nsColor.withAlphaComponent(0.98)))
        static let backgroundHover = BeamColor.Custom(named: "FormatterBackgroundHoverColor")
        static let border = BeamColor.Custom(named: "FormatterBorderColor")
        static let shadow = BeamColor.From(color: NSColor(withLightColor: NSColor.black.withAlphaComponent(0.25), darkColor: NSColor.black.withAlphaComponent(0.60)))
        static let icon = BeamColor.Corduroy
        static let iconHoverAndActive = BeamColor.Niobium
        static let buttonBackgroundHover = BeamColor.Custom(named: "FormatterItemHoverColor")
    }
}

extension BeamColor {
    enum PointShoot {
        static let text = BeamColor.From(color: BeamColor.Beam.nsColor)
        static let pointBackground = BeamColor.From(color: NSColor(
            withLightColor: BeamColor.Beam.nsColor.withAlphaComponent(0.14),
            darkColor: BeamColor.Beam.nsColor.withAlphaComponent(0.20)
        ))
        static let shootBackground = BeamColor.From(color: NSColor(
            withLightColor: BeamColor.Beam.nsColor.withAlphaComponent(0.28),
            darkColor: BeamColor.Beam.nsColor.withAlphaComponent(0.40)
        ))
        static let reminiscenceBackground = BeamColor.From(color: NSColor(
            withLightColor: BeamColor.Beam.nsColor.withAlphaComponent(0.14),
            darkColor: BeamColor.Beam.nsColor.withAlphaComponent(0.20)
        ))
    }
}

extension BeamColor {
    enum Autocomplete {
        static let link = BeamColor.Bluetiful
        static let subtitleText = BeamColor.LightStoneGray
        static let newCardSubtitle = BeamColor.From(color: NSColor(withLightColor: BeamColor.Beam.nsColor.withAlphaComponent(0.7), darkColor: BeamColor.Beam.nsColor))
        static let selectedBackground = BeamColor.Generic.textSelection
        static let clickedBackground = BeamColor.From(color: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.14))
        static let focusedBackground = BeamColor.From(color: NSColor(withLightColor: NSColor.white, darkColor: BeamColor.Nero.nsColor))
        static let focusedShadow = BeamColor.From(color: NSColor(withLightColor: BeamColor.Niobium.nsColor.withAlphaComponent(0.15), darkColor: NSColor.black.withAlphaComponent(0.6)))
        static let focusedPressedShadow = BeamColor.From(color: NSColor(withLightColor: BeamColor.Niobium.nsColor.withAlphaComponent(0.2), darkColor: NSColor.black.withAlphaComponent(0.8)))
        static let hoveredShadow = BeamColor.From(color: NSColor(withLightColor: BeamColor.Niobium.nsColor.withAlphaComponent(0.07), darkColor: NSColor.black.withAlphaComponent(0.4)))
    }
}

extension BeamColor {
    enum NotePicker {
        static let border = BeamColor.Mercury
        static let selected = BeamColor.From(color: NSColor(
            withLightColor: BeamColor.Beam.nsColor.withAlphaComponent(0.10),
            darkColor: BeamColor.Beam.nsColor.withAlphaComponent(0.20)
        ))
        static let active = BeamColor.From(color: NSColor(
            withLightColor: BeamColor.Beam.nsColor.withAlphaComponent(0.20),
            darkColor: BeamColor.Beam.nsColor.withAlphaComponent(0.30)
        ))
    }
}

extension BeamColor {
    enum BottomBar {
        static let shadow = BeamColor.From(color: NSColor(withLightColor: NSColor.black.withAlphaComponent(0.050), darkColor: BeamColor.Mercury.nsColor))
    }
}

extension BeamColor {
    enum Button {
        static let activeBackground = BeamColor.Mercury
        static let text = BeamColor.LightStoneGray
        static let activeText = BeamColor.Niobium
    }
}

extension BeamColor {
    enum Passwords {
        static let hoverBackground = BeamColor.From(color: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.10))
        static let activeBackground = BeamColor.From(color: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.14))
    }
}

// MARK: - Cursor & Selection
extension BeamColor.Generic {
    static private let possibleCursorColors = [
        BeamColor.From(color: BeamColor.Niobium.nsColor.withAlphaComponent(0.6)),
        BeamColor.From(color: BeamColor.Niobium.nsColor.withAlphaComponent(0.45)),
        BeamColor.From(color: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.6)),
        BeamColor.From(color: BeamColor.Beam.nsColor.withAlphaComponent(0.6)),
        BeamColor.From(color: BeamColor.Shiraz.nsColor.withAlphaComponent(0.6)),
        BeamColor.From(color: BeamColor.CharmedGreen.nsColor.withAlphaComponent(0.6))
    ]
    static private let possibleSelectionColors = [
        BeamColor.From(color: NSColor(withLightColor: BeamColor.Niobium.nsColor.withAlphaComponent(0.1),
                                      darkColor: BeamColor.Niobium.nsColor.withAlphaComponent(0.2))),
        BeamColor.From(color: NSColor(withLightColor: BeamColor.Niobium.nsColor.withAlphaComponent(0.075),
                                      darkColor: BeamColor.Niobium.nsColor.withAlphaComponent(0.15))),
        BeamColor.From(color: NSColor(withLightColor: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.1),
                                      darkColor: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.2))),
        BeamColor.From(color: NSColor(withLightColor: BeamColor.Beam.nsColor.withAlphaComponent(0.1),
                                      darkColor: BeamColor.Beam.nsColor.withAlphaComponent(0.2))),
        BeamColor.From(color: NSColor(withLightColor: BeamColor.Shiraz.nsColor.withAlphaComponent(0.1),
                                      darkColor: BeamColor.Shiraz.nsColor.withAlphaComponent(0.2))),
        BeamColor.From(color: NSColor(withLightColor: BeamColor.CharmedGreen.nsColor.withAlphaComponent(0.1),
                                      darkColor: BeamColor.CharmedGreen.nsColor.withAlphaComponent(0.2)))
    ]
    static private let randomCursorColorIndex = Int.random(in: 0..<6)

    static let cursor = possibleCursorColors[randomCursorColorIndex]
    static let textSelection = possibleSelectionColors[randomCursorColorIndex]
}

extension BeamColor {
    enum CalendarPicker {
        static let selectedDayBackground = BeamColor.From(color: NSColor(withLightColor: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.08),
                                                                         darkColor: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.14)))
        static let selectedDayHoverBackground = BeamColor.From(color: NSColor(withLightColor: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.14),
                                                                              darkColor: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.24)))
        static let selectedDayClickedBackground = BeamColor.From(color: NSColor(withLightColor: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.2),
                                                                                darkColor: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.4)))

        static let dayHoverBackground = BeamColor.From(color: NSColor(withLightColor: BeamColor.Mercury.nsColor,
                                                                      darkColor: BeamColor.AlphaGray.nsColor))
        static let dayClickedBackground = BeamColor.From(color: NSColor(withLightColor: BeamColor.AlphaGray.nsColor,
                                                                        darkColor: BeamColor.LightStoneGray.nsColor))
    }
}
