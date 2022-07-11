//
//  RightClickMenuViewLocators.swift
//  BeamUITests
//
//  Created by Quentin Valero on 06/07/2022.
//

import Foundation

enum RightClickMenuViewLocators {
    
    enum ImageMenuItems: String, CaseIterable, UIElement {
        case openImageInNewTab = "Open Image in New Tab"
        case openImageInNewWindow = "Open Image in New Window"
        case saveToDownloads = "Save Image to \"Downloads\""
        case saveAs = "Save Image As..."
        case copyImageAddress = "Copy Image Address"
        case copyImage = "Copy Image"
    }
    
    enum LinkMenuItems: String, CaseIterable, UIElement {
        case openLinkInNewTab = "Open Link in New Tab"
        case openLinkInNewWindow = "Open Link in New Window"
        case downloadLinkedFile = "Download Linked File"
        case downloadLinkedFileAs = "Download Linked File As..."
        case copyLink = "Copy Link"
        case services = "Services"
    }
    
    enum TextMenuItems: String, CaseIterable, UIElement {
        case lookUpText = "WKMenuItemIdentifierLookUp"
        case translateText = "WKMenuItemIdentifierTranslate"
        case searchWithGoogle = "Search with Google"
        case copyText = "Copy"
        case speech = "Speech"
        case services = "Services"
    }
    
    enum CommonMenuItems: String, CaseIterable, UIElement {
        case share = "WKMenuItemIdentifierShareMenu"
        case inspectElement = "Inspect Element"
    }
    
    enum ShareCommonMenuItems: String, CaseIterable, UIElement {
        case shareByMail = "Mail"
        case shareByMessages = "Messages"
        case shareByNote = "Notes"
        case shareMoreOptions = "More…"
    }
    
    enum ShareImageMenuItems: String, CaseIterable, UIElement {
        case shareByPhotos = "Add to Photos"
    }
    
    enum ServicesMenuItems: String, CaseIterable, UIElement {
        case serviceMusic = "Add to Music as a Spoken Track"
        case serviceOpen = "Open"
        case serviceOpenManPage = "Open man Page in Terminal"
        case serviceSearchManPage = "Search man Page Index in Terminal"
        case serviceSearchGoogle = "Search With Google"
        case serviceShowInFinder = "Show in Finder"
        case serviceShowInfoInFinder = "Show Info in Finder"
    }
    
    enum SpeechCommonMenuItems: String, CaseIterable, UIElement {
        case startSpeaking = "Start Speaking"
        case stopSpeaking = "Stop Speaking"
    }
}
