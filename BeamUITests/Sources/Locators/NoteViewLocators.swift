//
//  NoteViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 06.08.2021.
//

import Foundation

enum NoteViewLocators {
    
    enum Groups: String, CaseIterable, UIElement {
        case slashContextMenu = "ContextMenu"
    }
    
    enum ContextMenuItems: String, CaseIterable, UIElement {
        case cardReferenceItem = "ContextMenuItem-note reference"
        case todoItem = "ContextMenuItem-todo"
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
    
    enum Others: String, CaseIterable, UIElement {
        case beginningPartOfContextItem = "ContextMenuItem-"
    }

}
