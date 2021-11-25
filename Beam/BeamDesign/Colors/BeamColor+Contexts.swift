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
        static let bidirectionalLinkBackground = BeamColor.Beam.alpha(0.08)
        static let bidirectionalLinkHighlightedBackground = BeamColor.Beam.alpha(0.24)
        static let bidirectionalUnderline = BeamColor.Beam.alpha(0.25)
        static let control = BeamColor.Custom(named: "EditorControlColor")
        static let link = BeamColor.Niobium
        static let linkActive = BeamColor.Bluetiful
        static let linkActiveBackground = BeamColor.Bluetiful.alpha(0.1)
        static let linkActiveHighlightedBackground = BeamColor.Bluetiful.alpha(0.24)
        static var linkDecoration = BeamColor.combining(lightColor: .AlphaGray, darkColor: .LightStoneGray)
        static let syntax = BeamColor.Custom(named: "EditorSyntaxColor")
        static let indentBackground = BeamColor.combining(lightColor: .Mercury, lightAlpha: 0.5, darkColor: .Mercury)
        static let underlineAndStrikethrough = BeamColor.Niobium

        static let sourceButtonBackground = BeamColor.Nero
        static let sourceButtonBackgroundHover = BeamColor.Niobium
        static let sourceButtonBackgroundClicked = BeamColor.Niobium

        static let sourceButtonStroke = BeamColor.Custom(named: "EditorSourceButtonStroke").alpha(0.2)
        static let sourceButtonStrokeHover = BeamColor.From(color: .white, alpha: 0.2)
        static let sourceButtonStrokeClicked = BeamColor.From(color: .white, alpha: 0.2)
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
        static let background = BeamColor.combining(lightColor: .From(color: NSColor.white), lightAlpha: 0.98,
                                                    darkColor: .Nero, darkAlpha: 0.98)
        static let backgroundHover = BeamColor.Custom(named: "FormatterBackgroundHoverColor")
        static let border = BeamColor.Custom(named: "FormatterBorderColor")
        static let shadow = BeamColor.combining(lightColor: .From(color: .black), lightAlpha: 0.25,
                                                darkColor: .From(color: .black), darkAlpha: 0.6)
        static let icon = BeamColor.Corduroy
        static let iconHoverAndActive = BeamColor.Niobium
        static let buttonBackgroundHover = BeamColor.Custom(named: "FormatterItemHoverColor")
    }
}

extension BeamColor {
    enum PointShoot {
        static let text = BeamColor.From(color: BeamColor.Beam.nsColor)
        static let pointBackground = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.14,
                                                         darkColor: .Beam, darkAlpha: 0.2)
        static let shootBackground = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.28,
                                                         darkColor: .Beam, darkAlpha: 0.4)
        static let reminiscenceBackground = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.14,
                                                                darkColor: .Beam, darkAlpha: 0.2)
    }
}

extension BeamColor {
    enum Autocomplete {
        static let link = BeamColor.Bluetiful
        static let subtitleText = BeamColor.LightStoneGray
        static let newCardSubtitle = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.7,
                                                         darkColor: .Beam)
        static let selectedBackground = BeamColor.Bluetiful.alpha(0.1)
        static let clickedBackground = BeamColor.Bluetiful.alpha(0.16)
        static let selectedCardBackground = BeamColor.Beam.alpha(0.1)
        static let clickedCardBackground = BeamColor.Beam.alpha(0.16)
        static let focusedBackground = BeamColor.combining(lightColor: .From(color: .white), darkColor: .Nero)
        static let focusedShadow = BeamColor.combining(lightColor: .Niobium, lightAlpha: 0.15,
                                                       darkColor: .From(color: .black), darkAlpha: 0.6)
        static let focusedPressedShadow = BeamColor.combining(lightColor: .Niobium, lightAlpha: 0.2,
                                                              darkColor: .From(color: .black), darkAlpha: 0.8)
        static let hoveredShadow = BeamColor.combining(lightColor: .Niobium, lightAlpha: 0.07,
                                                       darkColor: .From(color: .black), darkAlpha: 0.4)
    }
}

extension BeamColor {
    enum NotePicker {
        static let border = BeamColor.Mercury
        static let selected = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.1,
                                                  darkColor: .Beam, darkAlpha: 0.2)
        static let active = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.2,
                                                darkColor: .Beam, darkAlpha: 0.3)
    }
}

extension BeamColor {
    enum ToolBar {
        static let shadowTop = BeamColor.combining(lightColor: .From(color: .black), lightAlpha: 0.050,
                                                   darkColor: .Mercury)
        static let shadowBottom = BeamColor.combining(lightColor: .From(color: .black), lightAlpha: 0.1,
                                                      darkColor: .Mercury)
        static let secondaryBackground = BeamColor.combining(lightColor: .Mercury, darkColor: BeamColor.Custom(named: "BrowserTabSecondaryBackground"))
        static let hoveredSecondaryAdditionalBackground =
            BeamColor.combining(lightColor: .Niobium.alpha(0.07), darkColor: BeamColor.Custom(named: "BrowserTabHoveredAdditionalBackground"))
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
    enum ActionableButtonBlue {
        static let background = BeamColor.Bluetiful.alpha(0.1)
        static let backgroundHovered = BeamColor.combining(lightColor: .Bluetiful, lightAlpha: 0.16,
                                                           darkColor: .Bluetiful, darkAlpha: 0.2)
        static let backgroundClicked = BeamColor.combining(lightColor: .Bluetiful, lightAlpha: 0.28,
                                                           darkColor: .Bluetiful, darkAlpha: 0.34)
        static let backgroundDisabled = BeamColor.combining(lightColor: .Bluetiful, lightAlpha: 0.04,
                                                            darkColor: .Bluetiful, darkAlpha: 0.07)
        static let foreground = BeamColor.Bluetiful
        static let disabledForeground = BeamColor.combining(lightColor: .Bluetiful, lightAlpha: 0.15,
                                                            darkColor: .Bluetiful, darkAlpha: 0.2)
    }

    enum ActionableButtonPurple {
        static let background = BeamColor.Beam.alpha(0.1)
        static let backgroundHovered = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.16,
                                                           darkColor: .Beam, darkAlpha: 0.2)
        static let backgroundClicked = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.28,
                                                           darkColor: .Beam, darkAlpha: 0.34)
        static let backgroundDisabled = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.04,
                                                            darkColor: .Beam, darkAlpha: 0.07)
        static let foreground = BeamColor.Beam
        static let disabledForeground = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.15,
                                                            darkColor: .Beam, darkAlpha: 0.2)
    }

    enum ActionableButtonSecondary {
        static let background = BeamColor.combining(lightColor: .Nero, darkColor: .Mercury)
        static let backgroundHovered = BeamColor.combining(lightColor: .Mercury, darkColor: .AlphaGray)
        static let backgroundClicked = BeamColor.combining(lightColor: .AlphaGray, darkColor: .LightStoneGray)
        static let foreground = BeamColor.Corduroy
        static let backgroundDisabled = BeamColor.Nero
        static let activeForeground = BeamColor.Niobium
        static let disabledForeground = BeamColor.AlphaGray.alpha(0.5)
        static let icon = BeamColor.AlphaGray
        static let iconHovered = BeamColor.LightStoneGray
        static let iconActive = BeamColor.Corduroy
        static let iconDisabled = BeamColor.AlphaGray.alpha(0.5)
    }
}

extension BeamColor {
    enum Passwords {
        static let hoverBackground = BeamColor.Bluetiful.alpha(0.10)
        static let activeBackground = BeamColor.Bluetiful.alpha(0.14)
    }
}

extension BeamColor {
    enum Search {
        static let foundElement = BeamColor.Custom(named: "SearchResult")
        static let foundElementHover = BeamColor.Custom(named: "SearchResultHover")
        static let currentElement = BeamColor.Custom(named: "CurrentSearchResult")
        static let currentElementHover = BeamColor.Custom(named: "CurrentSearchResultHover")
    }
}

// MARK: - Cursor & Selection
extension BeamColor.Generic {
    static private let possibleCursorColors = [
        BeamColor.Niobium.alpha(0.6),
        BeamColor.Niobium.alpha(0.45),
        BeamColor.Bluetiful.alpha(0.6),
        BeamColor.Beam.alpha(0.6),
        BeamColor.Shiraz.alpha(0.6),
        BeamColor.CharmedGreen.alpha(0.6)
    ]
    static private let possibleSelectionColors = [
        BeamColor.combining(lightColor: .Niobium, lightAlpha: 0.1,
                            darkColor: .Niobium, darkAlpha: 0.2),
        BeamColor.combining(lightColor: .Niobium, lightAlpha: 0.075,
                            darkColor: .Niobium, darkAlpha: 0.15),
        BeamColor.combining(lightColor: .Bluetiful, lightAlpha: 0.1,
                            darkColor: .Bluetiful, darkAlpha: 0.2),
        BeamColor.combining(lightColor: .Beam, lightAlpha: 0.1,
                            darkColor: .Beam, darkAlpha: 0.2),
        BeamColor.combining(lightColor: .Shiraz, lightAlpha: 0.1,
                            darkColor: .Shiraz, darkAlpha: 0.2),
        BeamColor.combining(lightColor: .CharmedGreen, lightAlpha: 0.1,
                            darkColor: .CharmedGreen, darkAlpha: 0.2)
    ]
    static private let randomCursorColorIndex = Int.random(in: 0..<6)

    static let cursor = possibleCursorColors[randomCursorColorIndex]
    static let textSelection = possibleSelectionColors[randomCursorColorIndex]
    static let blueTextSelection = BeamColor.combining(lightColor: .Bluetiful, lightAlpha: 0.14,
                                                       darkColor: .Bluetiful, darkAlpha: 0.4)
}

extension BeamColor {
    enum CalendarPicker {
        // default theme
        static let selectedDayBackground = BeamColor.combining(lightColor: .Bluetiful, lightAlpha: 0.08,
                                                               darkColor: .Bluetiful, darkAlpha: 0.14)
        static let selectedDayHoverBackground = BeamColor.combining(lightColor: .Bluetiful, lightAlpha: 0.14,
                                                                    darkColor: .Bluetiful, darkAlpha: 0.24)
        static let selectedDayClickedBackground = BeamColor.combining(lightColor: .Bluetiful, lightAlpha: 0.2,
                                                                      darkColor: .Bluetiful, darkAlpha: 0.4)
        static let dayHoverBackground = BeamColor.combining(lightColor: .Mercury, darkColor: .AlphaGray)
        static let dayClickedBackground = BeamColor.combining(lightColor: .AlphaGray, darkColor: .LightStoneGray)

        // beam theme
        static let beamSelectedDayBackground = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.08,
                                                                   darkColor: .Beam, darkAlpha: 0.14)
        static let beamSelectedDayHoverBackground = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.14,
                                                                        darkColor: .Beam, darkAlpha: 0.24)
        static let beamSelectedDayClickedBackground = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.2,
                                                                          darkColor: .Beam, darkAlpha: 0.4)
    }
}

extension BeamColor {
    enum Gradient {
        static let beamGradientStart = BeamColor.From(color: NSColor(deviceRed: 184/255, green: 102/255, blue: 255/255, alpha: 1))
        static let beamGradientEnd = BeamColor.From(color: NSColor(deviceRed: 116/255, green: 51/255, blue: 255/255, alpha: 1))
    }
}
