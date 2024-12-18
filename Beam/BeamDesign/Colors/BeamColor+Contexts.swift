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
        static let tableViewBackground = BeamColor.Custom(named: "macOSTableViewBackground")
        static let tableViewStroke = BeamColor.Custom(named: "macOSTableViewStroke")

        /// -> light: Generic.background / dark: Mercury
        static let secondaryBackground = BeamColor.combining(lightColor: .Generic.background, darkColor: .Mercury)
        /// -> Niobium
        static let text = BeamColor.Niobium
        /// -> LightStoneGray
        static let subtitle = BeamColor.LightStoneGray
        /// -> AlphaGray
        static let placeholder = BeamColor.AlphaGray
        static let transparent = BeamColor.Custom(named: "Transparent")
        /// -> Mercury
        static let separator = BeamColor.Mercury

        static let macOSContextSeparator = BeamColor.Custom(named: "macOSContextSeparator")
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
        static let bidirectionalLinkBackground = BeamColor.combining(lightColor: .Beam.alpha(0.05), darkColor: .Beam.alpha(0.10))
        static let bidirectionalLinkHighlightedBackground = BeamColor.combining(lightColor: .Beam.alpha(0.15), darkColor: .Beam.alpha(0.18))
        static let bidirectionalUnderline = BeamColor.Beam.alpha(0.25)
        static let control = BeamColor.Custom(named: "EditorControlColor")
        static let link = BeamColor.Niobium
        static let linkActive = BeamColor.Bluetiful
        static let linkActiveBackground = BeamColor.combining(lightColor: .Bluetiful.alpha(0.05), darkColor: .Bluetiful.alpha(0.08))
        static let linkActiveHighlightedBackground = BeamColor.combining(lightColor: .Bluetiful.alpha(0.15), darkColor: .Bluetiful.alpha(0.15))
        static var linkDecoration = BeamColor.combining(lightColor: .AlphaGray, darkColor: .LightStoneGray)
        static let syntax = BeamColor.Custom(named: "EditorSyntaxColor")
        static let indentBackground = BeamColor.combining(lightColor: .Mercury, lightAlpha: 0.5, darkColor: .Mercury)
        static let underlineAndStrikethrough = BeamColor.Niobium
        static let reference = BeamColor.combining(lightColor: .Niobium, lightAlpha: 0.75, darkColor: .Niobium, darkAlpha: 0.65)
        static let moveHandleHover = BeamColor.Niobium

        //Like Nero, but always in light mode
        static let sourceButtonBackground = BeamColor.Custom(named: "EditorSourceButtonBackground")
        //Like Niobium, but always in light mode
        static let sourceButtonBackgroundHover = BeamColor.Custom(named: "EditorSourceButtonBackgroundHover")
        static let sourceButtonBackgroundClicked = BeamColor.Custom(named: "EditorSourceButtonBackgroundHover")

        static let sourceButtonStroke = BeamColor.Custom(named: "EditorSourceButtonStroke").alpha(0.2)
        static let sourceButtonStrokeHover = BeamColor.From(color: .white, alpha: 0.2)
        static let sourceButtonStrokeClicked = BeamColor.From(color: .white, alpha: 0.2)

        static let collapseExpandButton = BeamColor.LightStoneGray
        static let collapseExpandButtonHover = BeamColor.Bluetiful
        static let collapseExpandButtonClicked = BeamColor.Custom(named: "EditorSearchClicked")
        static let tokenNoLinkActiveBackground = BeamColor.combining(lightColor: .Mercury, lightAlpha: 0.5, darkColor: .AlphaGray, darkAlpha: 0.5)
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
        static let placeholder = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.5,
                                                     darkColor: .Beam, darkAlpha: 0.7)
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
        static let selectedBackground = BeamColor.combining(lightColor: Bluetiful, lightAlpha: 0.14, darkColor: Bluetiful, darkAlpha: 0.24)
        static let clickedBackground = BeamColor.combining(lightColor: Bluetiful, lightAlpha: 0.2, darkColor: Bluetiful, darkAlpha: 0.34)
        static let selectedCardBackground = BeamColor.combining(lightColor: Beam, lightAlpha: 0.1, darkColor: Beam, darkAlpha: 0.24)
        static let clickedCardBackground = BeamColor.combining(lightColor: Beam, lightAlpha: 0.16, darkColor: Beam, darkAlpha: 0.34)
        static let focusedBackground = BeamColor.combining(lightColor: .From(color: .white), darkColor: .Nero)
        static let focusedShadow = BeamColor.combining(lightColor: .Niobium, lightAlpha: 0.15,
                                                       darkColor: .From(color: .black), darkAlpha: 0.6)
        static let focusedPressedShadow = BeamColor.combining(lightColor: .Niobium, lightAlpha: 0.2,
                                                              darkColor: .From(color: .black), darkAlpha: 0.8)
        static let hoveredShadow = BeamColor.combining(lightColor: .Niobium, lightAlpha: 0.07,
                                                       darkColor: .From(color: .black), darkAlpha: 0.4)
        static let separatorColor = BeamColor.combining(lightColor: .Mercury, lightAlpha: 0.8,
                                                        darkColor: .Mercury, darkAlpha: 0.3)
        static let selectedActionBackground = BeamColor.combining(lightColor: .Mercury, lightAlpha: 0.9, darkColor: .Nero, darkAlpha: 0.65)
        static let clickedActionBackground = BeamColor.combining(lightColor: .AlphaGray, lightAlpha: 0.6, darkColor: .AlphaGray, darkAlpha: 0.6)
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
        static let backgroundInactiveWindow = BeamColor.combining(lightColor: .Mercury, darkColor: .Nero)
        static let backgroundBottomSeparator = BeamColor.combining(lightColor: From(color: .black), lightAlpha: 0.1, darkColor: From(color: .white), darkAlpha: 0.1)
        static let backgroundBottomSeparatorWeb = BeamColor.combining(lightColor: From(color: .black), lightAlpha: 0.15, darkColor: From(color: .black), darkAlpha: 0.75)
        static let backgroundBottomSeparatorInactiveWindow = BeamColor.combining(lightColor: From(color: .black), lightAlpha: 0.2, darkColor: From(color: .black), darkAlpha: 0.75)
        static let horizontalSeparator = BeamColor.combining(lightColor: .Mercury, darkColor: .Nero, darkAlpha: 0.75)
        static let shadowTop = BeamColor.combining(lightColor: .From(color: .black), lightAlpha: 0.050,
                                                   darkColor: .Mercury)
        static let shadowBottom = BeamColor.combining(lightColor: .From(color: .black), lightAlpha: 0.1,
                                                      darkColor: .Mercury)
        static let secondaryBackground = BeamColor.combining(lightColor: .Mercury, darkColor: BeamColor.Custom(named: "BrowserTabSecondaryBackground"))
        static let hoveredSecondaryAdditionalBackground =
            BeamColor.combining(lightColor: .Niobium.alpha(0.07), darkColor: BeamColor.Custom(named: "BrowserTabHoveredAdditionalBackground"))

        static let buttonForeground = BeamColor.LightStoneGray
        static let buttonForegroundInactiveWindow = BeamColor.AlphaGray
        static let buttonForegroundDisabled = BeamColor.AlphaGray.alpha(0.5)
        static let buttonForegroundHoveredClicked = BeamColor.Generic.text
        static let buttonBackgroundClicked = BeamColor.Mercury

        static let capsuleStroke = BeamColor.combining(lightColor: From(color: .black), lightAlpha: 0.1, darkColor: From(color: .white), darkAlpha: 0.20)
        static let capsuleStrokeClicked = BeamColor.combining(lightColor: From(color: .black), lightAlpha: 0.1, darkColor: From(color: .white), darkAlpha: 0.25)
        static let capsuleTabForegroundStroke = BeamColor.combining(lightColor: From(color: .black), lightAlpha: 0.1, darkColor: From(color: .white), darkAlpha: 0.25)
        static let capsuleTabStrokeClicked = BeamColor.combining(lightColor: From(color: .black), lightAlpha: 0.1, darkColor: From(color: .white), darkAlpha: 0.45)
        static let capsuleForegroundBackground = BeamColor.combining(lightColor: .Generic.background, darkColor: .Mercury)
        static let capsuleIncognitoTabForegroundStroke = BeamColor.combining(lightColor: From(color: .black), lightAlpha: 0.55, darkColor: From(color: .white), darkAlpha: 0.1)
        static let capsuleIncognitoForegroundBackground = BeamColor.combining(lightColor: .Corduroy, darkColor: .Niobium)
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
    enum ActionableButtonBeam {
        static let background = BeamColor.Beam
        static let backgroundHovered = BeamColor.combining(lightColor: BeamColor.From(color: NSColor(red: 0.196, green: 0, blue: 0.898, alpha: 1)), lightAlpha: 1,
                                                           darkColor: BeamColor.From(color: NSColor(red: 0.482, green: 0.38, blue: 1, alpha: 1)), darkAlpha: 1)
        static let backgroundClicked = BeamColor.combining(lightColor: BeamColor.From(color: NSColor(red: 0.173, green: 0, blue: 0.8, alpha: 1)), lightAlpha: 1,
                                                           darkColor: BeamColor.From(color: NSColor(red: 0.4, green: 0.278, blue: 1, alpha: 1)), darkAlpha: 1)
        static let backgroundDisabled = BeamColor.Generic.background.alpha(0)
        static let strokeDisabled = BeamColor.Beam
        static let foreground = BeamColor.From(color: .white)
        static let disabledForeground = BeamColor.Beam.alpha(0.4)
    }

    enum ActionableButtonBlue {
        static let background = BeamColor.Bluetiful.alpha(0.1)
        static let backgroundHovered = BeamColor.combining(lightColor: .Bluetiful, lightAlpha: 0.16,
                                                           darkColor: .Bluetiful, darkAlpha: 0.2)
        static let backgroundClicked = BeamColor.combining(lightColor: .Bluetiful, lightAlpha: 0.28,
                                                           darkColor: .Bluetiful, darkAlpha: 0.34)
        static let backgroundDisabled = BeamColor.Generic.transparent
        static let strokeDisabled = BeamColor.combining(lightColor: .Bluetiful, lightAlpha: 0.15,
                                                                  darkColor: .Bluetiful, darkAlpha: 0.4)
        static let foreground = BeamColor.Bluetiful
        static let disabledForeground = BeamColor.Bluetiful.alpha(0.4)
    }

    enum ActionableButtonPurple {
        static let background = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.1, darkColor: .Beam, darkAlpha: 0.28)
        static let backgroundHovered = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.16,
                                                           darkColor: .Beam, darkAlpha: 0.38)
        static let backgroundClicked = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.28,
                                                           darkColor: .Beam, darkAlpha: 0.50)
        static let backgroundDisabled = BeamColor.Generic.transparent
        static let strokeDisabled = BeamColor.combining(lightColor: .Beam, lightAlpha: 0.15,
                                                                  darkColor: .Beam, darkAlpha: 0.2)
        static let foreground = BeamColor.Beam
        static let disabledForeground = BeamColor.Beam.alpha(0.4)
    }

    enum ActionableButtonSecondary {
        static let background = BeamColor.combining(lightColor: .Mercury, darkColor: .AlphaGray, darkAlpha: 0.64)
        static let backgroundHovered = BeamColor.combining(lightColor: .AlphaGray, lightAlpha: 0.6,
                                                           darkColor: .LightStoneGray, darkAlpha: 0.8)
        static let backgroundClicked = BeamColor.combining(lightColor: .AlphaGray, lightAlpha: 0.8,
                                                           darkColor: .LightStoneGray, darkAlpha: 0.75)
        static let foreground = BeamColor.Niobium
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
    enum WebFieldAutofill {
        static let fieldButtonBackgroundHovered = BeamColor.Nero.alpha(0.5) // light version is used, regardless of actual mode
        static let fieldButtonIcon = BeamColor.LightStoneGray // light version is used, regardless of actual mode
        static let fieldButtonIconHovered = BeamColor.Niobium // light version is used, regardless of actual mode
        static let popupBackground = BeamColor.combining(lightColor: .From(color: NSColor(white: 1.0, alpha: 0.92) + BeamColor.Mercury.alpha(0.20).nsColor(for: .aqua)),
                                                         darkColor: .From(color: NSColor(red: 28.0/255.0, green: 28.0/255.0, blue: 31.0/255.0, alpha: 0.92) + BeamColor.Mercury.alpha(0.80).nsColor(for: .darkAqua)))
        static let autofillCellBackgroundHovered = BeamColor.combining(lightColor: .Bluetiful.alpha(0.10), darkColor: .Bluetiful.alpha(0.14))
        static let autofillCellBackgroundClicked = BeamColor.combining(lightColor: .Bluetiful.alpha(0.16), darkColor: .Bluetiful.alpha(0.20))
        static let actionCellBackgroundHovered = BeamColor.combining(lightColor: .Nero, darkColor: .Nero.alpha(0.30))
        static let actionCellBackgroundClicked = BeamColor.combining(lightColor: .Mercury, darkColor: .Mercury.alpha(0.50))
        static let icon = BeamColor.Corduroy
        static let primaryText = BeamColor.Generic.text
        static let secondaryText = BeamColor.Generic.subtitle
        static let actionLabel = BeamColor.Generic.subtitle
        static let actionLabelHovered = BeamColor.Corduroy
        static let actionLabelClicked = BeamColor.Niobium
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

extension BeamColor {
    enum WebViewStatusBar {
        static let text = BeamColor.Corduroy.alpha(0.85)
        static let emphasizedText = BeamColor.Corduroy
        static let background = BeamColor.Nero.alpha(0.5)
        static let border = BeamColor.combining(
            lightColor: From(color: .black), lightAlpha: 0.1,
            darkColor: From(color: .white), darkAlpha: 0.1
        )
    }
}

// MARK: - Cursor & Selection
extension BeamColor {
    enum Cursor: String, CaseIterable {
        typealias ColorTuple = (nsColor: NSColor, cgColor: CGColor)

        static var `default`: Self { .whiteBlack }

        static var current: Self { .init(rawValue: PreferencesManager.cursorColor) ?? .default }

        static private(set) var cache: (cursor: ColorTuple, selection: ColorTuple, widget: ColorTuple) = {
            let color = current
            let (cursor, selection, widget) = (color.color, color.selectionColor, color.widgetColor)
            return ((cursor.nsColor, cursor.cgColor), (selection.nsColor, selection.cgColor), (widget.nsColor, widget.cgColor))
        }()

        case whiteBlack
        case gray
        case blue
        case purple
        case red
        case green

        var color: BeamColor {
            switch self {
            case .whiteBlack:   return .Niobium
            case .gray:         return .LightStoneGray
            case .blue:         return .Bluetiful.alpha(0.6)
            case .purple:       return .Beam.alpha(0.6)
            case .red:          return .Shiraz.alpha(0.6)
            case .green:        return .CharmedGreen.alpha(0.6)
            }
        }

        private var selectionColor: BeamColor {
            switch self {
            case .whiteBlack:   return .combining(lightColor: .Niobium, lightAlpha: 0.34, darkColor: .Niobium, darkAlpha: 0.34)
            case .gray:         return .combining(lightColor: .LightStoneGray, lightAlpha: 0.44, darkColor: .LightStoneGray, darkAlpha: 0.54)
            case .blue:         return .combining(lightColor: .Bluetiful, lightAlpha: 0.34, darkColor: .Bluetiful, darkAlpha: 0.44)
            case .purple:       return .combining(lightColor: .Beam, lightAlpha: 0.34, darkColor: .Beam, darkAlpha: 0.44)
            case .red:          return .combining(lightColor: .Shiraz, lightAlpha: 0.34, darkColor: .Shiraz, darkAlpha: 0.44)
            case .green:        return .combining(lightColor: .CharmedGreen, lightAlpha: 0.34, darkColor: .CharmedGreen, darkAlpha: 0.44)
            }
        }

        private var widgetColor: BeamColor {
            switch self {
            case .whiteBlack:   return .combining(lightColor: .Niobium, lightAlpha: 0.12, darkColor: .Niobium, darkAlpha: 0.12)
            case .gray:         return .combining(lightColor: .LightStoneGray, lightAlpha: 0.16, darkColor: .LightStoneGray, darkAlpha: 0.24)
            case .blue:         return .combining(lightColor: .Bluetiful, lightAlpha: 0.12, darkColor: .Bluetiful, darkAlpha: 0.16)
            case .purple:       return .combining(lightColor: .Beam, lightAlpha: 0.12, darkColor: .Beam, darkAlpha: 0.16)
            case .red:          return .combining(lightColor: .Shiraz, lightAlpha: 0.12, darkColor: .Shiraz, darkAlpha: 0.16)
            case .green:        return .combining(lightColor: .CharmedGreen, lightAlpha: 0.12, darkColor: .CharmedGreen, darkAlpha: 0.16)
            }
        }

        static func updateCache(newCursorColor: Cursor = .current) {
            let (cursor, selection, widget) = (newCursorColor.color, newCursorColor.selectionColor, newCursorColor.widgetColor)
            cache = ((cursor.nsColor, cursor.cgColor), (selection.nsColor, selection.cgColor), (widget.nsColor, widget.cgColor))
        }
    }
}

extension BeamColor.Generic {
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

extension BeamColor {
    enum Shortcut {
        static let background = BeamColor.combining(lightColor: .Nero, darkColor: .Nero, darkAlpha: 0.3)
    }
}

extension BeamColor {
    enum Sidebar {
        static let background = BeamColor.Nero.alpha(0.4)
    }
}

extension BeamColor {
    enum TabGrouping {
        static let red        = BeamColor.Custom(named: "tabgroupRed")
        static let redText    = BeamColor.Custom(named: "tabgroupRedText")
        static let yellow     = BeamColor.Custom(named: "tabgroupYellow")
        static let yellowText = BeamColor.Custom(named: "tabgroupYellowText")
        static let green      = BeamColor.Custom(named: "tabgroupGreen")
        static let greenText  = BeamColor.Custom(named: "tabgroupGreenText")
        static let cyan       = BeamColor.Custom(named: "tabgroupCyan")
        static let cyanText   = BeamColor.Custom(named: "tabgroupCyanText")
        static let blue       = BeamColor.Custom(named: "tabgroupBlue")
        static let blueText   = BeamColor.Custom(named: "tabgroupBlueText")
        static let pink       = BeamColor.Custom(named: "tabgroupPink")
        static let pinkText   = BeamColor.Custom(named: "tabgroupPinkText")
        static let purple     = BeamColor.Custom(named: "tabgroupPurple")
        static let purpleText = BeamColor.Custom(named: "tabgroupPurpleText")
        static let birgit     = BeamColor.Custom(named: "tabgroupBirgit")
        static let birgitText = BeamColor.Custom(named: "tabgroupBirgitText")
        static let gray       = BeamColor.Custom(named: "tabgroupGray")
        static let grayText   = BeamColor.Custom(named: "tabgroupGrayText")
    }
}
