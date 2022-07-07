//
//  RightClickMenuViewLocators.swift
//  BeamUITests
//
//  Created by Quentin Valero on 06/07/2022.
//

import Foundation

enum RightClickMenuViewLocators {
    
    enum MenuItems: String, CaseIterable, UIElement {
        case openImageInNewTab = "Open Image in New Tab"
        case openImageInNewWindow = "Open Image in New Window"
        case saveToDownloads = "Save Image to \"Downloads\""
        case saveAs = "Save Image As..."
        case copyImageAddress = "Copy Image Address"
        case copyImage = "Copy Image"
        case share = "WKMenuItemIdentifierShareMenu"
        case inspectElement = "Inspect Element"

    }
    
    enum ShareMenuItems: String, CaseIterable, UIElement {
        case shareByMail = "Mail"
        case shareByMessages = "Messages"
        case shareByNote = "Notes"
        case shareByPhotos = "Add to Photos"
        case shareMoreOptions = "More…"

    }
    
}
