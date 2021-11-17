//
//  HelpViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation

enum HelpViewLocators {
    
    enum StaticTexts: String, CaseIterable, UIElement  {
        case shortcuts = "Shortcuts"
        case feature = "Feature Request"
        case bug = "Report a bug"
        case menuTitle = "Help & Feedback"
        case closeShortcuts = "Done"
    }

    enum Images: String, CaseIterable, UIElement  {
        case closeHelp = "tool-close"
        case cmdLabel = "shortcut-cmd"
    }
}
