//
//  AddLinkViewLocators.swift
//  BeamUITests
//
//  Created by Quentin Valero on 06/06/2022.
//

import Foundation

enum AddLinkViewLocators {
    
    enum TextFields: String, CaseIterable, UIElement  {
        case linkTitleEmpty = "Title"
        case linkUrl = "Link URL"
    }
    
    enum Images: String, CaseIterable, UIElement  {
        case copyIcon = "editor-url_copy"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case linkCopiedLabel = "Opened in background"
    }

}
