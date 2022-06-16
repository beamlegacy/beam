//
//  BeamWebContextMenu.swift
//  Beam
//
//  Created by Adam Viaud on 01/06/2022.
//

/// Menu Items appearing in Context Menu from webviews.
enum BeamWebContextMenuItem {
    case pageBack
    case pageForward
    case pageReload
    case pagePrint
    case pageCopyAddress
    case pageCapture

    case linkOpenInNewTab
    case linkOpenInNewWindow
    case linkCopy
    case linkCapture

    case imageOpenInNewTab
    case imageOpenInNewWindow
    case imageSaveToDownloads
    case imageSaveAs
    case imageCopyAddress
    case imageCapture

    case textSearch
    case textCopy
    case textCapture

    case separator

    case systemImageCopy
    case systemLookUp
    case systemTranslate
    case systemSpeech
    case systemShare
    case systemInspectElement
}

/// Errors possibly thrown when interacting with items within Context Menu from webviews.
enum BeamWebContextMenuItemError: Error {
    /// The payload received from the message handler is invalid.
    case invalidPayload
    /// An unexpected error occured.
    case unexpectedError
    /// The item is unimplemented and should have not been visible.
    case unimplemented
}
