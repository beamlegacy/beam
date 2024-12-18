//
//  BrowserPreferencesViewLocators.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 22.06.2022.
//

import Foundation

enum BrowserPreferencesViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case importButton = "Import..."
        case downloadFolderButton = "preferences-folder-icon"
        case setDefaultButton = "Set Default..."
        case searchEngine = "search-engine-selector"
        case clearCacheButton = "clear-cache-button"
    }

    enum StaticTexts: String, CaseIterable, UIElement {
        case importPasswordlabel = "Import your passwords and history from other browsers."
    }
    
    enum MenuItemsDownload: String, CaseIterable, UIElement {
        case downloads = "Downloads"
        case other = "Other…"
    }
    
    enum MenuItemsSearchEngine: String, CaseIterable, UIElement {
        case google = "Google"
        case duck = "DuckDuckGo"
        case ecosia = "Ecosia"
    }
    
    enum Checkboxes: String, CaseIterable, UIElement {
        case searchEngine = "search-engine-suggestion"
        case cmdClick = "cmd-click-checkbox"
        case switchTabs = "switch-tabs-checkbox"
        case captureSounds = "capture-sounds-checkbox"
        case groupTabs = "group-tabs-checkbox"
        case videoCallWindow = "videoCalls-always-in-side-window-checkbox"
    }
}
