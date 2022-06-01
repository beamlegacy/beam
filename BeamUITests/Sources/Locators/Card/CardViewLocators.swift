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
    
    enum DisclosureTriangles: String, CaseIterable, UIElement {
        case indentationArrow = "node_arrow"
        case editorArrowDown = "editor-arrow_down"
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case editorOptions = "editor-options"
        case contextMenuRename = "ContextMenuItem-rename"
        case privateLock = "status-lock"
        case editorButton = "editor-breadcrumb_down"
        case copyCardLinkButton = "editor-url_link"
        case linksSection = "LinksSection"
        case referencesSection = "ReferencesSection"
        case linkButton = "link-reference-button"
        case linkAllButton = "link-all-references-button"
        case deleteCardButton = "editor-delete"
        case publishCardButton = "NoteHeaderPublishButton"
        case unpublishCardButton = "Unpublish"
        case linkNamesButton = "cardTitleLayer"
        case sourceButton = "source"
        case expandButton = "global-expand"
        case imageNoteCollapsedView = "collapsed-text"
        case linkReferenceCounterTitle = "sectionTitle"
        case breadcrumbTitle = "breadcrumb0"
        case noteMediaPlaying = "note-media-playing"
        case noteMediaMuted = "note-media-muted"
        case moveHandle = "moveHandle"
        case newNoteCreation = "NewNoteButton"
        case checkbox = "checkbox"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case noteTitle = "Note's title"
        case textNode = "TextNode"
        case imageNode = "ImageNode"
        case embedNode = "EmbedNode"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case privateLabel = "Private"
        case publishedLabel = "Published"
        case linkCopiedLabel = "Link Copied"
        case publishLabel = "ContextMenuItem-publish"
        case unpublishLabel = "ContextMenuItem-unpublish"
        case copyLinkLabel = "ContextMenuItem-copy link"
        case blockRefLock = "ContextMenuItem-lock"
        case blockRefUnlock = "ContextMenuItem-unlock"
        case blockRefRemove = "ContextMenuItem-remove"
        case blockRefOrigin = "ContextMenuItem-view origin"
        case backgroundTabOpened = "Opened in background"
    }
    
    enum TextViews: String, CaseIterable, UIElement {
        case linksRefsLabel = "ProxyTextNode"
        case linksRefsTitle = "RefNoteTitle"
        case blockReference = "BlockReferenceNode"
    }
    
    enum OtherElements: String, CaseIterable, UIElement {
        case breadCrumb = "BreadCrumb"
    }
    
    enum Splitters: String, CaseIterable, UIElement {
        case noteDivider = "DividerNode"
    }
    
}
