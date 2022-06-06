//
//  AllNotesTableLocators.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 25.05.2022.
//

import Foundation

enum AllNotesTableLocators {
    
    enum SortButtons: String, CaseIterable, UIElement {
        case title = "Title"
        case URL = "URL"
        case words = "Words"
        case links = "Links"
        case updated = "Updated"
    }
    
    enum Images: String, CaseIterable, UIElement {
        case viewsExtendToggle = "editor-breadcrumb_down"
    }
}
