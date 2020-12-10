//
//  NSColor+Beam.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 09/12/2020.
//

import Foundation
import Cocoa

extension NSColor {

    static var autoCompleteText: NSColor {
        return loadColor(named: "AutoCompleteText")
    }

    static var autoCompleteTextSelected: NSColor {
        return loadColor(named: "AutoCompleteTextSelected")
    }

    static var editorBackgroundColor: NSColor {
        return loadColor(named: "EditorBackgroundColor")
    }

    static var editorBidirectionalLinkColor: NSColor {
        return loadColor(named: "EditorBidirectionalLinkColor")
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
        return loadColor(named: "EditorLinkColor")
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
        return loadColor(named: "EditorTextColor")
    }

    static var editorTextRectangleBackgroundColor: NSColor {
        return loadColor(named: "EditorTextRectangleBackgroundColor")
    }

    static var editorTextSelectionColor: NSColor {
        return loadColor(named: "EditorTextSelectionColor")
    }

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
        return loadColor(named: "TextColor")
    }

    static var omniboxBackgroundColor: NSColor {
        return loadColor(named: "OmniboxBackgroundColor")
    }

    static var omniboxPlaceholderTextColor: NSColor {
        return loadColor(named: "OmniboxPlaceholderTextColor")
    }

    static var omniboxTextColor: NSColor {
        return loadColor(named: "OmniboxTextColor")
    }

    static var omniboxTextSelectionColor: NSColor {
        return loadColor(named: "OmniboxTextSelectionColor")
    }

    static var toolbarBackgroundColor: NSColor {
        return loadColor(named: "ToolbarBackgroundColor")
    }

    static var toolbarButtonBackgroundHoverColor: NSColor {
        return loadColor(named: "ToolbarButtonBackgroundHoverColor")
    }

    static var toolbarButtonBackgroundOnColor: NSColor {
        return loadColor(named: "ToolbarButtonBackgroundOnColor")
    }

    static var toolbarButtonIconColor: NSColor {
        return loadColor(named: "ToolbarButtonIconColor")
    }

    static var toolbarButtonIconDisabledColor: NSColor {
        return loadColor(named: "ToolbarButtonIconDisabledColor")
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
