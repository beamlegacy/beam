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
        static let placeholder = BeamColor.AlphaGray
        static let transparent = BeamColor.Custom(named: "Transparent")
        static let separator = BeamColor.Mercury
        static let textSelection = BeamColor.From(color: BeamColor.Bluetiful.nsColor.withAlphaComponent(0.1))
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
        static let control = BeamColor.Custom(named: "EditorControlColor")
        static let link = BeamColor.Niobium
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
        static let sectionTitle = BeamColor.LightStoneGray
        static let actionButtonBackgroundHover = BeamColor.Mercury
        static let actionButtonHover = BeamColor.Niobium
        static let actionButton = BeamColor.LightStoneGray
        static let chevronIcon = BeamColor.LightStoneGray
        static let breadcrumb = BeamColor.LightStoneGray
        static let breadcrumbHover = BeamColor.Niobium
        static let separator = BeamColor.Tundora
        static let title = BeamColor.Beam
        static let container = BeamColor.Custom(named: "EditorLinkContainer")
    }
}

extension BeamColor {
    enum BidirectionalPopover {
        static let background = BeamColor.Custom(named: "PopoverBackgroudColor")
        static let backgroundHover = BeamColor.Custom(named: "PopoverBackgroundHoverColor")
        static let actionText = BeamColor.Custom(named: "PopoverActionTextColor")
    }
}

extension BeamColor {
    enum Formatter {
        static let background = BeamColor.From(color: NSColor(withLightColor: NSColor.white.withAlphaComponent(0.98), darkColor: BeamColor.Nero.nsColor.withAlphaComponent(0.98)))
        static let backgroundHover = BeamColor.Custom(named: "FormatterBackgroundHoverColor")
        static let border = BeamColor.Custom(named: "FormatterBorderColor")
        static let shadow = BeamColor.From(color: NSColor(withLightColor: NSColor.black.withAlphaComponent(0.070), darkColor: NSColor.black.withAlphaComponent(0.4)))
        static let icon = BeamColor.Corduroy
        static let iconHoverAndActive = BeamColor.Niobium
        static let buttonBackgroundHover = BeamColor.Custom(named: "FormatterItemHoverColor")
    }
}

extension BeamColor {
    enum PointShoot {
        static let point = BeamColor.Custom(named: "PointColor")
        static let shootOutline = BeamColor.Custom(named: "ShootOutlineColor")
        static let shootBackground = BeamColor.Custom(named: "ShootBackgroundColor")
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
        static let focusedShadow = BeamColor.From(color: NSColor(withLightColor: NSColor.black.withAlphaComponent(0.1), darkColor: NSColor.black.withAlphaComponent(0.6)))
        static let hoveredShadow = BeamColor.From(color: NSColor(withLightColor: NSColor.black.withAlphaComponent(0.05), darkColor: NSColor.black.withAlphaComponent(0.4)))
    }
}

extension BeamColor {
    enum NotePicker {
        static let border = BeamColor.Mercury
        static let selected = BeamColor.From(color: BeamColor.Beam.nsColor.withAlphaComponent(0.03))
        static let active = BeamColor.From(color: BeamColor.Beam.nsColor.withAlphaComponent(0.08))
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
