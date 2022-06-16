//
//  BeamWebContextMenu.swift
//  Beam
//
//  Created by Adam Viaud on 01/06/2022.
//

import AppKit
import UniformTypeIdentifiers

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
}

enum BeamWebContextMenuItemError: Error {
    case invalidPayload
    case unexpectedError
    case unimplemented
}

extension BeamWebContextMenuItem {
    static func items(with payload: ContextMenuMessageHandlerPayload, from webView: BeamWebView, menu: NSMenu) -> [NSMenuItem] {
        return content(for: payload).compactMap { $0.nsMenuItem(from: webView, payload: payload, menu: menu) }
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
                .systemShare, .systemSpeech
            ]
        case .link:
            return [
                .linkOpenInNewTab, .linkOpenInNewWindow,
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
        case .linkPlusImage(let href, let src):
            var items = Self.content(for: .image(src: src)) + [.separator] + Self.content(for: .link(href: href))
            // Making sure share item is the last one
            guard let shareItemIndex = items.firstIndex(where: { $0.systemItemIdentifierEquivalent == .webKitSharing })
            else { return items }
            let shareItem = items.remove(at: shareItemIndex)
            return items + [shareItem]
        }
    }
}

extension BeamWebContextMenuItem {
    typealias ActionHandler = (BeamWebView, ContextMenuMessageHandlerPayload, (@escaping (Result<Void, Error>) -> Void)) -> Void

    func nsMenuItem(from webView: BeamWebView, payload: ContextMenuMessageHandlerPayload, menu: NSMenu) -> NSMenuItem? {
        let menuItem: NSMenuItem
        switch self {
        case .separator:
            menuItem = .separator()
        case .systemImageCopy, .systemLookUp, .systemTranslate, .systemSpeech, .systemShare:
            guard let identifierEquivalent = systemItemIdentifierEquivalent else { return nil }
            guard let equivalentItem = menu.items.first(where: { $0.identifier == identifierEquivalent }) else { return nil }
            menuItem = equivalentItem
        default:
            guard let title = title else { return nil }
            menuItem = HandlerMenuItem(title: title) { _ in
                guard let action = action else {
                    assertionFailure("This item shouldn't be available if there is no action available"); return
                }
                action(webView, payload) { result in
                    if case .failure(let error) = result {
                        UserAlert.showError(error: error)
                    }
                }
            }
        }
        menuItem.isEnabled = isEnabled(context: webView, payload: payload)
        menuItem.isHidden = isHidden
        return menuItem
    }

    private var action: ActionHandler? {
        return { webView, payload, result in
            switch self {
            case .pageBack:
                webView.goBack()
                result(.success(()))
            case .pageForward:
                webView.goForward()
                result(.success(()))
            case .pageReload:
                webView.reload()
                result(.success(()))
            case .pagePrint:
                result(printPage(webView: webView))
            case .pageCopyAddress:
                guard let url = payload.linkHrefURL else { return result(.failure(BeamWebContextMenuItemError.invalidPayload)) }
                result(copy(url.absoluteString, toPasteboard: .general, forType: .URL))
            case .linkOpenInNewTab:
                guard let url = payload.linkHrefURL else { return result(.failure(BeamWebContextMenuItemError.invalidPayload)) }
                result(openURLInNewTab(url))
            case .linkOpenInNewWindow:
                guard let url = payload.linkHrefURL else { return result(.failure(BeamWebContextMenuItemError.invalidPayload)) }
                result(openURLInNewWindow(url))
            case .linkCopy:
                guard let url = payload.linkHrefURL else { return result(.failure(BeamWebContextMenuItemError.invalidPayload)) }
                result(copy(url.absoluteString, toPasteboard: .general, forType: .URL))
            case .imageOpenInNewTab:
                guard let src = payload.imageSrcURL else { return result(.failure(BeamWebContextMenuItemError.invalidPayload)) }
                result(openURLInNewTab(src))
            case .imageOpenInNewWindow:
                guard let src = payload.imageSrcURL else { return result(.failure(BeamWebContextMenuItemError.invalidPayload)) }
                result(openURLInNewWindow(src))
            case .imageSaveToDownloads:
                guard let dstURL = getDestinationURL(for: payload) else { return result(.failure(BeamWebContextMenuItemError.unexpectedError)) }
                retrieveAndSaveImage(to: dstURL, payload: payload, webView: webView, bounceDownloadsStack: true, completion: result)
            case .imageSaveAs:
                showSaveAsPanel(payload: payload, webView: webView, completion: result)
            case .imageCopyAddress:
                guard let src = payload.imageSrcURL else { return result(.failure(BeamWebContextMenuItemError.invalidPayload)) }
                result(copy(src.absoluteString, toPasteboard: .general, forType: .URL))
            case .textSearch:
                result(search(with: payload))
            case .textCopy:
                guard case .textSelection(let contents) = payload else { return result(.failure(BeamWebContextMenuItemError.invalidPayload)) }
                result(copy(contents, toPasteboard: .general, forType: .string))
            case .textCapture, .imageCapture, .linkCapture, .pageCapture:
                result(.failure(BeamWebContextMenuItemError.unimplemented))
            case .separator:
                assertionFailure("This action shouldn't have any action associated to it")
                result(.failure(BeamWebContextMenuItemError.unexpectedError))
            case .systemImageCopy, .systemShare, .systemSpeech, .systemLookUp, .systemTranslate:
                assertionFailure("This action shouldn't be called since it's a system action")
                result(.success(()))
            }
        }
    }

    private var systemItemIdentifierEquivalent: NSUserInterfaceItemIdentifier? {
        switch self {
        case .systemImageCopy:  return .webKitCopyImage
        case .systemLookUp:     return .webKitTextLookUp
        case .systemTranslate:  return .webKitTextTranslate
        case .systemSpeech:     return .webKitSpeech
        case .systemShare:      return .webKitSharing
        default:                return nil
        }
    }

    private var title: String? {
        switch self {
        case .pageBack:             return "Back"
        case .pageForward:          return "Forward"
        case .pageReload:           return "Reload Page"
        case .pagePrint:            return "Print Page..."
        case .pageCopyAddress:      return "Copy Page Address"
        case .pageCapture:          return "Capture Page"
        case .linkOpenInNewTab:     return "Open Link in New Tab"
        case .linkOpenInNewWindow:  return "Open Link in New Window"
        case .linkCopy:             return "Copy Link"
        case .linkCapture:          return "Capture Link"
        case .imageOpenInNewTab:    return "Open Image in New Tab"
        case .imageOpenInNewWindow: return "Open Image in New Window"
        case .imageSaveToDownloads:
            let downloadsFolder = DownloadFolder(rawValue: PreferencesManager.selectedDownloadFolder) ?? .downloads
            return "Save Image to \"\(downloadsFolder.sandboxAccessibleUrl?.lastPathComponent ?? downloadsFolder.name)\""
        case .imageSaveAs:          return "Save Image as..."
        case .imageCopyAddress:     return "Copy Image Address"
        case .imageCapture:         return "Capture Image"
        case .textSearch:           return "Search with \(AppDelegate.main.window?.state.searchEngineName ?? "Google")"
        case .textCopy:             return "Copy"
        case .textCapture:          return "Capture Text Selection"
        case .separator, .systemImageCopy, .systemShare, .systemSpeech, .systemLookUp, .systemTranslate:
            return nil
        }
    }

    private var isHidden: Bool {
        switch self {
        case .pageCapture, .textCapture, .linkCapture, .imageCapture:
            return true
        default:
            return false
        }
    }

    private func isEnabled(context: BeamWebView, payload: ContextMenuMessageHandlerPayload) -> Bool {
        switch self {
        case .pageCapture, .textCapture, .linkCapture, .imageCapture:
            return false
        case .pageBack:
            return context.canGoBack
        case .pageForward:
            return context.canGoForward
        default:
            return true
        }
    }
}

extension BeamWebContextMenuItem {
    private func openURLInNewWindow(_ url: URL) -> Result<Void, Error> {
        let window = AppDelegate.main.createWindow(frame: nil, becomeMain: false)
        window?.state.createTab(withURLRequest: .init(url: url))
        window?.makeKeyAndOrderFront(nil)
        return .success(())
    }

    private func openURLInNewTab(_ url: URL) -> Result<Void, Error> {
        AppDelegate.main.window?.state.createTab(withURLRequest: .init(url: url), setCurrent: false)
        return .success(())
    }

    private func copy(_ string: String, toPasteboard pasteboard: NSPasteboard, forType type: NSPasteboard.PasteboardType) -> Result<Void, Error> {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: type)
        return .success(())
    }

    private func search(with payload: ContextMenuMessageHandlerPayload) -> Result<Void, Error> {
        let state = AppDelegate.main.window?.state
        guard case .textSelection(let contents) = payload, let tuple = state?.urlFor(query: contents), let url = tuple.0 else {
            return .failure(BeamWebContextMenuItemError.unexpectedError)
        }
        state?.createTab(withURLRequest: .init(url: url))
        return .success(())
    }

    private func printPage(webView: WKWebView) -> Result<Void, Error> {
        let info = NSPrintInfo.shared
        let operation = webView.printOperation(with: info)
        operation.view?.frame = webView.bounds
        guard let window = webView.window else { return .failure(BeamWebContextMenuItemError.unexpectedError) }
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        return .success(())
    }

    private func getDestinationURL(for payload: ContextMenuMessageHandlerPayload, fileManager: FileManager = .default) -> URL? {
        let downloadsFolder = DownloadFolder(rawValue: PreferencesManager.selectedDownloadFolder) ?? .downloads
        guard let src = payload.imageSrcURL, let downloadsFolderURL = downloadsFolder.sandboxAccessibleUrl else {
            return nil
        }
        return downloadsFolderURL.appendingPathComponent(src.lastPathComponent)
    }

    private func retrieveAndSaveImage(
        to dstURL: URL,
        overwrite: Bool = false,
        payload: ContextMenuMessageHandlerPayload,
        webView: BeamWebView,
        bounceDownloadsStack: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        func writeData(_ data: Data, dstURL: URL, overwrite: Bool, bounce: Bool) -> Result<Void, Error> {
            do {
                let availableDstURL = overwrite ? dstURL : dstURL.availableFileURL()
                let scopedURL = availableDstURL.deletingLastPathComponent()

                _ = scopedURL.startAccessingSecurityScopedResource() // below write will fail anyway if this returns false
                try data.write(to: availableDstURL)
                scopedURL.stopAccessingSecurityScopedResource()

                if bounce {
                    try? NSWorkspace.shared.bounceDockStack(with: availableDstURL)
                }

                return .success(())
            } catch {
                return .failure(error)
            }
        }

        func dispatchResult(_ result: Result<Data, Error>) {
            switch result {
            case .success(let data):
                completion(writeData(data, dstURL: dstURL, overwrite: overwrite, bounce: bounceDownloadsStack))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        var inferMimeType: Bool {
            #if BEAM_WEBKIT_ENHANCEMENT_ENABLED
            return true
            #else
            return false
            #endif
        }

        // Let's check if we're displaying a raw image and we have data available
        if inferMimeType, let mimeType = webView._MIMEType, let uti = UTType(mimeType: mimeType), uti.conforms(to: .image) {
            webView._getMainResourceData { dispatchResult(Result($0, $1)) }
        }
        // Otherwise, let's download the data
        else if let imageSrcURL = payload.imageSrcURL {
            downloadImage(url: imageSrcURL) { dispatchResult($0) }
        } else {
            completion(.failure(BeamWebContextMenuItemError.invalidPayload))
        }
    }

    private func showSaveAsPanel(
        payload: ContextMenuMessageHandlerPayload,
        webView: BeamWebView,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let window = webView.window else {
            completion(.failure(BeamWebContextMenuItemError.unexpectedError)); return
        }

        let nameFieldStringValue = payload.imageSrcURL?.lastPathComponent ?? ""

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = nameFieldStringValue
        savePanel.level = .modalPanel
        savePanel.beginSheetModal(for: window) { [weak savePanel] response in
            if response == NSApplication.ModalResponse.OK {
                guard let url = savePanel?.url else {
                    completion(.failure(BeamWebContextMenuItemError.unexpectedError)); return
                }
                retrieveAndSaveImage(
                    to: url,
                    overwrite: true,
                    payload: payload,
                    webView: webView,
                    bounceDownloadsStack: true,
                    completion: completion
                )
            } else if response == NSApplication.ModalResponse.cancel {
                completion(.success(())) // showing the panel was a success, user just decided to cancel...
            } else {
                completion(.failure(BeamWebContextMenuItemError.unexpectedError))
            }
        }
    }

    private func downloadImage(url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                completion(Result(data, error))
            }
        }.resume()
    }

}
