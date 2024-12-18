//
//  NoteViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 06.08.2021.
//

import Foundation

enum NoteViewLocators {
    
    enum Groups: String, CaseIterable, UIElement {
        case contextMenu = "ContextMenu"
    }
    
    enum SlashContextMenuItems: String, CaseIterable, UIElement {
        // slash menu options
        case noteItem = "ContextMenuItem-note"
        case todoCheckboxItem = "ContextMenuItem-todo"
        case datePickerItem = "ContextMenuItem-date picker"
        case boldItem = "ContextMenuItem-bold"
        case italicItem = "ContextMenuItem-italic"
        case strikethroughItem = "ContextMenuItem-strikethrough"
        case underlineItem = "ContextMenuItem-underline"
        case heading1Item = "ContextMenuItem-heading 1"
        case heading2Item = "ContextMenuItem-heading 2"
        case textItem = "ContextMenuItem-text"
        case dividerItem = "ContextMenuItem-divider"
    }

    enum ContextMenuItems: String, CaseIterable, UIElement {
        // other options (not in slash menu)
        case asEmbed = "ContextMenuItem-show as embed"
    }
    
    enum Others: String, CaseIterable, UIElement {
        case beginningPartOfContextItem = "ContextMenuItem-"
    }
    
    enum RightClickMenuItems: String, CaseIterable, UIElement {
        case openLink = "Open Link"
        case copyLink = "Copy Link"
        case showAsEmbed = "Show as Embed"
        case editLink = "Edit Link..."
        case removeLink = "Remove Link"
    }

}
