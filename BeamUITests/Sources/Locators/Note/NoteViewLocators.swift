//
//  NoteViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation

enum NoteViewLocators {
    
    enum Groups: String, CaseIterable, UIElement {
        case contextMenu = "ContextMenu"
        case tabGroupPrefix = "tab-group-"
    }
    
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
        case copyNoteLinkButton = "editor-url_link"
        case linksSection = "LinksSection"
        case referencesSection = "ReferencesSection"
        case linkButton = "link-reference-button"
        case linkAllButton = "link-all-references-button"
        case deleteNoteButton = "editor-delete"
        case publishNoteButton = "NoteHeaderPublishButton"
        case unpublishNoteButton = "Unpublish"
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
        case pinUnpinButton = "pin-unpin-button"
        case bullet = "bullet"
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
        case addToProfile = "ContextMenuItem-add to profile"
        case sharePublishedNote = "ContextMenuItem-share"
        case backgroundTabOpened = "Opened in background"
    }
    
    enum SharePublishedNote: String, CaseIterable, UIElement {
        case shareTwitter = "ContextMenuItem-twitter"
        case shareFacebook = "ContextMenuItem-facebook"
        case shareLinkedin = "ContextMenuItem-linkedin"
        case shareReddit = "ContextMenuItem-reddit"
        case shareCopyUrl = "ContextMenuItem-copy url"
    }
    
    enum TextViews: String, CaseIterable, UIElement {
        case linksRefsLabel = "ProxyTextNode"
        case linksRefsTitle = "RefNoteTitle"
        case blockReference = "BlockReferenceNode"
    }
    
    enum OtherElements: String, CaseIterable, UIElement {
        case breadCrumb = "BreadCrumb"
        case beginningPartOfContextItem = "ContextMenuItem-"
        case addToProfileToggle = "ContextMenuItem-add to profile-toggle"
    }
    
    enum Splitters: String, CaseIterable, UIElement {
        case noteDivider = "DividerNode"
    }
    
    enum SlashContextMenuItems: String, CaseIterable, UIElement {
        // slash menu options
        case noteItem = "ContextMenuItem-note"
        case todoCheckboxItem = "ContextMenuItem-todo"
        case datePickerItem = "ContextMenuItem-date picker"
        case boldItem = "ContextMenuItem-bold"
        case italicItem = "ContextMenuItem-italic"
        case strikethroughItem = "ContextMenuItem-strikethrough"
        case underlineItem = "ContextMenuItem-underline"
        case heading1Item = "ContextMenuItem-heading 1"
        case heading2Item = "ContextMenuItem-heading 2"
        case textItem = "ContextMenuItem-text"
        case dividerItem = "ContextMenuItem-divider"
    }
    
    enum ContextMenuItems: String, CaseIterable, UIElement {
        // other options (not in slash menu)
        case asEmbed = "ContextMenuItem-show as embed"
    }
    
    enum RightClickMenuItems: String, CaseIterable, UIElement {
        case openLink = "Open Link"
        case copyLink = "Copy Link"
        case showAsEmbed = "Show as Embed"
        case editLink = "Edit Link..."
        case removeLink = "Remove Link"
    }
    
}
