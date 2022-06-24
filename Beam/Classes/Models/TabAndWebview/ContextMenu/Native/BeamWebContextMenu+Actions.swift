//
//  BeamWebContextMenu+Actions.swift
//  Beam
//
//  Created by Adam Viaud on 16/06/2022.
//

import AppKit
import UniformTypeIdentifiers

extension BeamWebContextMenuItem {
    typealias ActionHandler = (BeamWebView, ContextMenuMessageHandlerPayload, (@escaping (Result<Void, Error>) -> Void)) -> Void

    func nsMenuItem(from webView: BeamWebView, payload: ContextMenuMessageHandlerPayload, menu: NSMenu) -> NSMenuItem? {
        let menuItem: NSMenuItem
        switch self {
        case .separator:
            menuItem = .separator()
        case .systemImageCopy, .systemLookUp, .systemTranslate, .systemSpeech, .systemShare, .systemInspectElement:
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
            case .linkDownloadLinkedFile:
                guard let dstURL = getDestinationURL(forImageResource: false, payload: payload) else {
                    return result(.failure(BeamWebContextMenuItemError.unexpectedError))
                }
                retrieveAndSaveFile(imageResource: false, to: dstURL, payload: payload, webView: webView, completion: result)
            case .linkDownloadLinkedFileAs:
                showSaveAsPanel(imageResource: false, payload: payload, webView: webView, completion: result)
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
                guard let dstURL = getDestinationURL(forImageResource: true, payload: payload) else {
                    return result(.failure(BeamWebContextMenuItemError.unexpectedError))
                }
                retrieveAndSaveFile(imageResource: true, to: dstURL, payload: payload, webView: webView, completion: result)
            case .imageSaveAs:
                showSaveAsPanel(imageResource: true, payload: payload, webView: webView, completion: result)
            case .imageCopyAddress:
                guard let src = payload.imageSrcURL else { return result(.failure(BeamWebContextMenuItemError.invalidPayload)) }
                result(copy(src.absoluteString, toPasteboard: .general, forType: .URL))
            case .textSearch:
                result(search(with: payload))
            case .textCopy:
                guard let contents = payload.contents else { return result(.failure(BeamWebContextMenuItemError.invalidPayload)) }
                result(copy(contents, toPasteboard: .general, forType: .string))
            case .textCapture, .imageCapture, .linkCapture, .pageCapture:
                result(.failure(BeamWebContextMenuItemError.unimplemented))
            case .separator:
                assertionFailure("This action shouldn't have any action associated to it")
                result(.failure(BeamWebContextMenuItemError.unexpectedError))
            case .systemImageCopy, .systemShare, .systemSpeech, .systemLookUp, .systemTranslate, .systemInspectElement:
                assertionFailure("This action shouldn't be called since it's a system action")
                result(.success(()))
            }
        }
    }

    private var systemItemIdentifierEquivalent: NSUserInterfaceItemIdentifier? {
        switch self {
        case .systemImageCopy:      return .webKitCopyImage
        case .systemLookUp:         return .webKitTextLookUp
        case .systemTranslate:      return .webKitTextTranslate
        case .systemSpeech:         return .webKitSpeech
        case .systemShare:          return .webKitSharing
        case .systemInspectElement: return .webKitInspectElement
        default:                    return nil
        }
    }

    private var title: String? {
        switch self {
        case .pageBack:                 return "Back"
        case .pageForward:              return "Forward"
        case .pageReload:               return "Reload Page"
        case .pagePrint:                return "Print Page..."
        case .pageCopyAddress:          return "Copy Page Address"
        case .pageCapture:              return "Capture Page"
        case .linkOpenInNewTab:         return "Open Link in New Tab"
        case .linkOpenInNewWindow:      return "Open Link in New Window"
        case .linkDownloadLinkedFile:   return "Download Linked File"
        case .linkDownloadLinkedFileAs: return "Download Linked File As..."
        case .linkCopy:                 return "Copy Link"
        case .linkCapture:              return "Capture Link"
        case .imageOpenInNewTab:        return "Open Image in New Tab"
        case .imageOpenInNewWindow:     return "Open Image in New Window"
        case .imageSaveToDownloads:
            let downloadsFolder = DownloadFolder(rawValue: PreferencesManager.selectedDownloadFolder) ?? .downloads
            return "Save Image to \"\(downloadsFolder.sandboxAccessibleUrl?.lastPathComponent ?? downloadsFolder.name)\""
        case .imageSaveAs:              return "Save Image As..."
        case .imageCopyAddress:         return "Copy Image Address"
        case .imageCapture:             return "Capture Image"
        case .textSearch:               return "Search with \(AppDelegate.main.window?.state.searchEngineName ?? "Google")"
        case .textCopy:                 return "Copy"
        case .textCapture:              return "Capture Text Selection"
        case .separator, .systemImageCopy, .systemShare, .systemSpeech, .systemLookUp, .systemTranslate, .systemInspectElement:
            return nil
        }
    }

    private var isHidden: Bool {
        switch self {
        case .pageCapture, .textCapture, .linkCapture, .imageCapture:   return true
        default:                                                        return false
        }
    }

    private func isEnabled(context: BeamWebView, payload: ContextMenuMessageHandlerPayload) -> Bool {
        switch self {
        case .pageCapture, .textCapture, .linkCapture, .imageCapture:   return false
        case .pageBack:                                                 return context.canGoBack
        case .pageForward:                                              return context.canGoForward
        default:                                                        return true
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
        guard let contents = payload.contents, let tuple = state?.urlFor(query: contents), let url = tuple.0 else {
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

    private func getDestinationURL(forImageResource: Bool, payload: ContextMenuMessageHandlerPayload) -> URL? {
        let src = forImageResource ? payload.imageSrcURL : payload.linkHrefURL
        let downloadsFolder = DownloadFolder(rawValue: PreferencesManager.selectedDownloadFolder) ?? .downloads
        guard let src = src, let downloadsFolderURL = downloadsFolder.sandboxAccessibleUrl else { return nil }
        return downloadsFolderURL.appendingPathComponent(src.lastPathComponent)
    }

    private func writeData(saveAsMenu: Bool, _ data: Data, dstURL: URL, fileName: String? = nil, fileExtension: String? = nil) -> Result<Void, Error> {
        do {
            var availableDstURL: URL = dstURL

            if !saveAsMenu {
                fileName.map { availableDstURL.appendPathComponent($0) }
                fileExtension.map { availableDstURL.appendPathExtension($0) }
                availableDstURL = availableDstURL.availableFileURL()
            }

            let scopedURL = availableDstURL.deletingLastPathComponent()
            _ = scopedURL.startAccessingSecurityScopedResource() // below write will fail anyway if this returns false
            try data.write(to: availableDstURL, options: saveAsMenu ? [] : [.withoutOverwriting])
            scopedURL.stopAccessingSecurityScopedResource()

            try? NSWorkspace.shared.bounceDockStack(with: availableDstURL)

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    private func retrieveAndSaveFile(
        imageResource: Bool,
        to dstURL: URL,
        saveAsMenu: Bool = false,
        payload: ContextMenuMessageHandlerPayload,
        webView: BeamWebView,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        func dispatchResult(_ result: Result<Data, Error>, fileName: String? = nil, fileExtension: String? = nil) {
            switch result {
            case .success(let data):
                completion(writeData(saveAsMenu: saveAsMenu, data, dstURL: dstURL, fileName: fileName, fileExtension: fileExtension))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        if imageResource {
            #if BEAM_WEBKIT_ENHANCEMENT_ENABLED
            // Let's check if we're displaying a raw image and we have data available
            if let mimeType = webView._MIMEType, let uti = UTType(mimeType: mimeType), uti.conforms(to: .image) {
                webView._getMainResourceData {
                    let fileExtension = payload.imageSrcURL?.pathExtension.isEmpty == true ? uti.preferredFilenameExtension : nil
                    dispatchResult(Result($0, $1), fileExtension: fileExtension)
                }
                return
            }
            #endif
            // Otherwise, let's check if the image is base64 encoded, passing an Unknown fileName and a preferred file extension
            if let (data, mimeType) = payload.base64 {
                dispatchResult(.success(data), fileName: "Unknown", fileExtension: UTType(mimeType: mimeType)?.preferredFilenameExtension)
            }
            // Otherwise, let's download the data
            else if let imageSrcURL = payload.imageSrcURL {
                downloadResource(url: imageSrcURL) { result in
                    if imageSrcURL.pathExtension.isEmpty, case .success(let data) = result, let fileExtension = data.preferredFileExtension {
                        dispatchResult(result, fileExtension: fileExtension)
                    } else {
                        dispatchResult(result)
                    }
                }
            } else {
                completion(.failure(BeamWebContextMenuItemError.invalidPayload))
            }
        } else {
            if let linkHrefURL = payload.linkHrefURL, let downloadManager = (webView.window as? BeamWindow)?.data.downloadManager {
                downloadManager.downloadFile(at: linkHrefURL, destinationURL: dstURL)
                completion(.success(()))
            } else {
                completion(.failure(BeamWebContextMenuItemError.invalidPayload))
            }
        }
    }

    private func showSaveAsPanel(
        imageResource: Bool,
        payload: ContextMenuMessageHandlerPayload,
        webView: BeamWebView,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let window = webView.window else {
            completion(.failure(BeamWebContextMenuItemError.unexpectedError)); return
        }

        let savePanel = NSSavePanel()

        let srcURL = imageResource ? payload.imageSrcURL : payload.linkHrefURL

        if let lastPathComponent = srcURL?.lastPathComponent, !lastPathComponent.isEmpty {
            savePanel.nameFieldStringValue = lastPathComponent
        } else {
            savePanel.nameFieldStringValue = "Unknown"
        }
        if imageResource, let uti = payload.inferredImageUTType(with: webView) {
            savePanel.allowedContentTypes = [uti]
        }

        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.level = .modalPanel

        savePanel.beginSheetModal(for: window) { [weak savePanel] response in
            if response == NSApplication.ModalResponse.OK {
                guard let url = savePanel?.url else {
                   completion(.failure(BeamWebContextMenuItemError.unexpectedError)); return
                }
                retrieveAndSaveFile(imageResource: imageResource, to: url, saveAsMenu: true, payload: payload, webView: webView, completion: completion)
            } else if response == NSApplication.ModalResponse.cancel {
                completion(.success(())) // showing the panel was a success, user just decided to cancel...
            } else {
                completion(.failure(BeamWebContextMenuItemError.unexpectedError))
            }
        }
    }

    private func downloadResource(url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                completion(Result(data, error))
            }
        }.resume()
    }
}

private extension ContextMenuMessageHandlerPayload {
    // to be used only within the save panel
    func inferredImageUTType(with webView: BeamWebView? = nil) -> UTType? {
        #if BEAM_WEBKIT_ENHANCEMENT_ENABLED
        if let mimeType = webView?._MIMEType, let uti = UTType(mimeType: mimeType), uti.conforms(to: .image) {
            return uti
        }
        #endif
        if let (_, mimeType) = base64 {
            return UTType(mimeType: mimeType)
        }
        return imageSrcURL.flatMap { UTType(mimeType: $0.pathExtension) }
    }
}
