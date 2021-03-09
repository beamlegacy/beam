//
//  NSColor+Beam.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 09/12/2020.
//

import Foundation
import Cocoa

extension NSColor {

    static var editorBackgroundColor: NSColor {
        return loadColor(named: "EditorBackgroundColor")
    }

    // Editor

    static var editorIconColor: NSColor {
        return loadColor(named: "LightStoneGray")
    }

    static var editorSearchNormal: NSColor {
        return loadColor(named: "EditorSearchNormal")
    }

    static var editorSearchHover: NSColor {
        return loadColor(named: "Bluetiful")
    }

    static var editorSearchClicked: NSColor {
        return loadColor(named: "EditorSearchClicked")
    }

    static var editorBidirectionalLinkColor: NSColor {
        return loadColor(named: "CharmedGreen")
    }

    static var editorControlColor: NSColor {
        return loadColor(named: "EditorControlColor")
    }

    static var editorFormattingBarBackgroundColor: NSColor {
        return loadColor(named: "EditorFormattingBarBackgroundColor")
    }

    static var editorFormattingButtonColor: NSColor {
        return loadColor(named: "EditorFormattingButtonColor")
    }

    static var editorLinkColor: NSColor {
        return loadColor(named: "Niobium")
    }

    static var editorPopoverBackgroundColor: NSColor {
        return loadColor(named: "EditorPopoverBackgroundColor")
    }

    static var editorPopoverTextColor: NSColor {
        return loadColor(named: "EditorPopoverTextColor")
    }

    static var editorSyntaxColor: NSColor {
        return loadColor(named: "EditorSyntaxColor")
    }

    static var editorTextColor: NSColor {
        return loadColor(named: "Niobium")
    }

    static var editorTextRectangleBackgroundColor: NSColor {
        return loadColor(named: "EditorTextRectangleBackgroundColor")
    }

    static var editorTextSelectionColor: NSColor {
        return loadColor(named: "EditorTextSelectionColor")
    }

    static var underlineAndstrikethroughColor: NSColor {
        return loadColor(named: "Niobium")
    }

    static var cardTitleColor: NSColor {
        return loadColor(named: "Niobium")
    }

    static var cardTimeColor: NSColor {
        return loadColor(named: "LightStoneGray")
    }

    static var cardOptionIconColor: NSColor {
        return loadColor(named: "LightStoneGray")
    }

    // Reference Linked

    static var linkedSectionTitleColor: NSColor {
        return loadColor(named: "LightStoneGray")
    }

    static var linkedActionButtonHoverColor: NSColor {
        return loadColor(named: "CharmedGreen")
    }

    static var linkedActionButtonColor: NSColor {
        return loadColor(named: "LightStoneGray")
    }

    static var linkedChevronIconColor: NSColor {
        return loadColor(named: "LightStoneGray")
    }

    static var linkedBreadcrumbColor: NSColor {
        return loadColor(named: "LightStoneGray")
    }

    static var linkedBreadcrumbHoverColor: NSColor {
        return loadColor(named: "Niobium")
    }

    static var linkedSeparatorColor: NSColor {
        return loadColor(named: "Tundora")
    }

    static var linkedTitleColor: NSColor {
        return loadColor(named: "CharmedGreen")
    }

    static var linkedContainerColor: NSColor {
        return loadColor(named: "Niobium")
    }

    // Popover

    static var bidirectionalPopoverBackgroundColor: NSColor {
        return loadColor(named: "PopoverBackgroudColor")
    }

    static var bidirectionalPopoverBackgroundHoverColor: NSColor {
        return loadColor(named: "PopoverBackgroundHoverColor")
    }

    static var bidirectionalPopoverTextColor: NSColor {
        return loadColor(named: "Niobium")
    }

    static var bidirectionalPopoverActionTextColor: NSColor {
        return loadColor(named: "PopoverActionTextColor")
    }

    // Formatter View

    static var formatterViewBackgroundColor: NSColor {
        return loadColor(named: "Alabaster")
    }

    static var formatterViewBackgroundColorDark: NSColor {
        return loadColor(named: "FormatterBackgroundColorDark")
    }

    static var formatterViewBackgroundColorLight: NSColor {
        return loadColor(named: "FormatterBackgroundColorLight")
    }

    static var formatterViewBackgroundHoverColor: NSColor {
        return loadColor(named: "FormatterBackgroundHoverColor")
    }

    static var formatterBorderColor: NSColor {
        return loadColor(named: "FormatterBorderColor")
    }

    static var formatterShadowColor: NSColor {
        return loadColor(named: "FormatterShadowColor")
    }

    static var formatterIconColor: NSColor {
        return loadColor(named: "Corduroy")
    }

    static var formatterIconHoverAndActiveColor: NSColor {
        return loadColor(named: "Niobium")
    }

    static var formatterActiveIconColor: NSColor {
        return loadColor(named: "FormatterActiveIconColor")
    }

    static var formatterButtonBackgroudHoverColor: NSColor {
        return loadColor(named: "FormatterItemHoverColor")
    }

    static var hyperlinkTextFielDefaultdColor: NSColor {
        return loadColor(named: "Niobium")
    }

    static var hyperlinkTextFielNoEmptydColor: NSColor {
        return loadColor(named: "LightStoneGray")
    }

    // Other

    static var tableHeaderTextColor: NSColor {
        return loadColor(named: "TableHeaderTextColor")
    }

    static var headerTextColor: NSColor {
        return loadColor(named: "HeaderTextColor")
    }

    static var tabBarBg: NSColor {
        return loadColor(named: "TabBarBg")
    }

    static var tabFrame: NSColor {
        return loadColor(named: "TabFrame")
    }

    static var tabHover: NSColor {
        return loadColor(named: "TabHover")
    }

    static var textColor: NSColor {
        return loadColor(named: "Niobium")
    }

    // Omnibox
    static var omniboxPlaceholderTextColor: NSColor {
        return loadColor(named: "LightStoneGray")
    }

    static var omniboxTextColor: NSColor {
        return loadColor(named: "Niobium")
    }

    // Autocomplete
    static var autocompleteTextColor: NSColor {
        return self.editorTextColor
    }

    static var autocompleteSubtitleTextColor: NSColor {
        return loadColor(named: "LightStoneGray")
    }

    static var autocompleteSelectedBackgroundColor: NSColor {
        return loadColor(named: "AutocompleteSelectedBackgroundColor")
    }

    // Destination Note
    static var destinationNoteBorderColor: NSColor {
        return loadColor(named: "Mercury")
    }

    static var destinationNoteTextColor: NSColor {
        return loadColor(named: "LightStoneGray")
    }

    static var destinationNoteActiveTextColor: NSColor {
        return loadColor(named: "Niobium")
    }

    // Toolbar
    static var toolbarButtonActiveBackgroundColor: NSColor {
        return loadColor(named: "Mercury")
    }

    static var toolbarButtonIconColor: NSColor {
        return loadColor(named: "LightStoneGray")
    }

    static var toolbarButtonActiveIconColor: NSColor {
        return loadColor(named: "Niobium")
    }

    static var toolbarButtonIconDisabledColor: NSColor {
        return toolbarButtonIconColor.withAlphaComponent(0.13)
    }

    static var transparent: NSColor {
        return loadColor(named: "transparent")
    }

    fileprivate class func loadColor(named: String) -> NSColor {
        guard let color = NSColor(named: named) else {
            fatalError("Couln't find \(named) color.")
        }

        return color
    }

}
