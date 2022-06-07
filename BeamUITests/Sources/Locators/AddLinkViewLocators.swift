//
//  AddLinkViewLocators.swift
//  BeamUITests
//
//  Created by Quentin Valero on 06/06/2022.
//

import Foundation

enum AddLinkViewLocators {
    
    enum TextFields: String, CaseIterable, UIElement  {
        case linkTitle = "link-title"
        case linkUrl = "link-url"
    }
    
    enum Images: String, CaseIterable, UIElement  {
        case copyIcon = "editor-url_copy"
        case shortcutReturn = "shortcut-return"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case linkCopiedLabel = "Opened in background"
    }

}
