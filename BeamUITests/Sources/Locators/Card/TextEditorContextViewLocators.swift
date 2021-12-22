//
//  TextContextViewLocators.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 20.12.2021.
//

import Foundation

enum TextEditorContextViewLocators {
    
    enum Images: String, CaseIterable, UIElement {
        case bold = "editor-format_bold"
        case italic = "editor-format_italic"
        case bidi = "editor-format_bidirectional"
        case link = "editor-format_link"
        case h1 = "editor-format_h1"
        case h2 = "editor-format_h2"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case linkTitle = "Title"
        case linkURL = "Link URL"
    }

}
