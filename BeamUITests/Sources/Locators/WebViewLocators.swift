//
//  TabsViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation

enum WebViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case closeTabButton = "tabs-close_xs"
        case destinationNote = "DestinationNoteTitle"
        case goToJournalButton = "journal"
        case goBackButton = "goBack"
        case goForwardButton = "goForward"
        case openOmnibox = "nav-omnibox"
    }
    
    enum SearchFields: String, CaseIterable, UIElement {
        case destinationNoteSearchField = "DestinationNoteSearchField"
    }
    
    enum Tabs: String, CaseIterable, UIElement {
        case tabPrefix = "TabItem-BrowserTab-"
        case tabPinnedPrefix = "TabItem-BrowserTab-pinned-"
        case tabURL = "browserTabURL"
        case tabTitle = "browserTabTitle"
    }
    
    enum Link: String, CaseIterable, UIElement {
        case autocompleteResult = "autocompleteResult"
    }
    
    enum PDFElements: String, CaseIterable, UIElement {
        case downloadButton = "save-pdf"
        case printButton = "download-file_print"
        case zoomInButton = "download-file_zoomin"
        case zoomOutButton = "download-file_zoomout"
        case zoomRatio = "zoom-level"
    }
    
    enum MenuItem: String, CaseIterable, UIElement {
        case pinTab = "Pin Tab"
        case unpinTab = "Unpin Tab"
        case closeTab = "Close Tab"
        case createTabGroup = "Create Tab Group"
        case addToGroup = "Add to Group"
        case ungroup = "Ungroup"
    }
    
}
