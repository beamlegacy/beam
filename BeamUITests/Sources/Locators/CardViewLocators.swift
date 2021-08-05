//
//  CardView.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation

enum CardViewLocators {
    
    enum ScrollViews: String, CaseIterable, UIElement {
        case noteView = "noteView"
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case editorOptions = "editor-options"
        case contextMenuRename = "ContextMenuItem-rename"
        case privateLock = "status-private"
        case editorButton = "editor-breadcrumb_down"
        case copyLinkButton = "editor-url_link"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case cardTitle = "Card's title"
        case noteField = "TextNode"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case privateLabel = "Private"
        case publishedLabel = "Published"
        case publishLabel = "ContextMenuItem-publish"
        case unpublishLabel = "ContextMenuItem-unpublish"
        case copyLinkLabel = "ContextMenuItem-copy link"
        case inviteLabel = "ContextMenuItem-invite..."
    }
    
}
