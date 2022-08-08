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
    case linkDownloadLinkedFile
    case linkDownloadLinkedFileAs
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

extension BeamWebContextMenuItem {
    static func items(with payload: ContextMenuMessageHandlerPayload, from webView: BeamWebView, menu: NSMenu) -> [NSMenuItem] {
        let items = content(for: payload) + [.separator, .systemInspectElement]
        return items.compactMap { $0.nsMenuItem(from: webView, payload: payload, menu: menu) }
    }

    private static func content(for payload: ContextMenuMessageHandlerPayload) -> [Self] {
        switch payload {
        case .page:
            return [
                .pageBack, .pageForward, .pageReload,
                .separator,
                .pagePrint,
                .separator,
                .pageCopyAddress, .pageCapture
            ]
        case .textSelection:
            return [
                .systemLookUp, .systemTranslate, .textSearch,
                .separator,
                .textCopy, .textCapture,
                .separator,
                .systemShare, .separator, .systemSpeech
            ]
        case .link:
            return [
                .linkOpenInNewTab, .linkOpenInNewWindow,
                .separator,
                .linkDownloadLinkedFile, .linkDownloadLinkedFileAs,
                .separator,
                .linkCopy, .linkCapture,
                .separator,
                .systemShare
            ]
        case .image:
            return [
                .imageOpenInNewTab, .imageOpenInNewWindow,
                .separator,
                .imageSaveToDownloads, .imageSaveAs,
                .separator,
                .imageCopyAddress, .systemImageCopy, .imageCapture,
                .separator,
                .systemShare
            ]
        case .multiple(let payloads):
            var items: [BeamWebContextMenuItem] = []
            for payload in payloads {
                items.append(contentsOf: Self.content(for: payload))
                items.append(.separator)
            }
            items.removeAll { $0 == .systemShare }
            return items + [.systemShare]
        case .ignored:
            assertionFailure("We shouldn't ask for any custom item for an ignored item")
            return []
        }
    }
}
