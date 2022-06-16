//
//  AllNotesViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation

enum AllNotesViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case newNoteButton = "tool new"
        case journalButton = "journal"
    }
    
    enum SortButtons: String, CaseIterable, UIElement {
        case title = "Title"
        case url = "URL"
        case words = "Words"
        case links = "Links"
        case updated = "Updated"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case newPrivateNote = "New Private Note"
        case newPublishedNote = "New Published Note"
        case newFirstPublishedNote = "You haven’t published any note yet. Start today!"
        case newPublishedProfileNote = "New Published on Profile Note"
        case newFirstPublishedProfileNote = "You haven’t published any note to your profile yet. Start today!"
    }
    
    enum ColumnCells: String, CaseIterable, UIElement {
        case noteTitleColumnCell = "Title"
    }
    
    enum Images: String, CaseIterable, UIElement {
        case singleNoteEditor = "editor-options"
        case allNotesEditor = "editor-breadcrumb_down"
    }
    
    enum MenuItems: String, CaseIterable, UIElement {
        case deleteNotes = "deleteNotes"
        case pinNote = "pin"
        case unpinNote = "unpin"
    }
    
    enum ViewMenuItems: String, CaseIterable, UIElement {
        case allNotes = "selectAllNotes"
        case privateNotes = "selectPrivateNotes"
        case publishedNotes = "selectPublishedNotes"
        case profileNotes = "selectOnProfileNotes"
        case dailyNotes = "showDailyNotes"
    }
    
    enum Others: String, CaseIterable, UIElement {
        case referenceSection = "ReferencesSection"
        case disclosureTriangle = "disclosure triangle"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case publishInstruction = "signUpToPublishBtn"
    }
}
