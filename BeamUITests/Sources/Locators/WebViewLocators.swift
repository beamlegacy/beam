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
    }
    
    enum SearchFields: String, CaseIterable, UIElement {
        case destinationNoteSearchField = "DestinationNoteSearchField"
    }
    
    enum Tabs: String, CaseIterable, UIElement {
        case tabPrefix = "TabItem-BrowserTab-"
        case tabURL = "browserTabURL"
        case tabTitle = "browserTabTitle"
    }
    
    enum Other: String, CaseIterable, UIElement {
        case autocompleteResult = "autocompleteResult"
    }
    
    enum PDFElements: String, CaseIterable, UIElement {
        case downloadButton = "download-file_download"
        case printButton = "download-file_print"
        case zoomInButton = "download-file_zoomin"
        case zoomOutButton = "download-file_zoomout"
        case zoomRatio = "pdf-toolbar"
    }
    
}
