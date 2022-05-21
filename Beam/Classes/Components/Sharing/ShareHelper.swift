//
//  ShareHelper.swift
//  Beam
//
//  Created by Remi Santos on 12/04/2022.
//

import Foundation
import BeamCore
import Combine

class ShareHelper {

    private let baseURL: URL?
    private let htmlNoteAdapter: HtmlNoteAdapter?
    private let openWebURL: (URL) -> Void
    private var imageCancellables = Set<AnyCancellable>()
    private let pasteboard: NSPasteboard

    init(_ baseURL: URL? = nil, htmlNoteAdapter: HtmlNoteAdapter? = nil, pasteboard: NSPasteboard = .general, handleOpenURL: @escaping (URL) -> Void) {
        self.baseURL = baseURL
        self.htmlNoteAdapter = htmlNoteAdapter
        self.openWebURL = handleOpenURL
        self.pasteboard = pasteboard
    }

    func shareContent(_ html: String, originURL: URL?, service: ShareService) async {
        guard let content = await getShareableContent(from: html) else { return }
        if service == .copy {
            await setContentToPasteboard(content)
        } else if let url = service.buildURL(with: content.text, url: content.url ?? originURL) {
            await handleURL(url)
        }
    }

    func share(link: URL, of noteTitle: String?, to service: ShareService) async {
        guard let url = service.buildURL(with: noteTitle ?? "", url: link) else { return }
        await handleURL(url)
    }

    private struct ReadShareableContent {
        var text: String?
        var url: URL?
        var elements: [BeamElement]?
    }

    private func getShareableContent(from html: String) async -> ReadShareableContent? {
        let elements: [BeamElement] = await withCheckedContinuation { continuation in
            guard let htmlNoteAdapter = htmlNoteAdapter else {
                continuation.resume(returning: [])
                return
            }
            htmlNoteAdapter.convert(html: html) { (beamElements: [BeamElement]) in
                continuation.resume(returning: beamElements)
            }
        }

        guard elements.count > 0 else { return nil }
        var texts: [String] = []
        var url: URL?
        elements.forEach { el in
            if !el.text.text.isEmpty {
                texts.append(el.text.text)
            }
        }
        if texts.count == 1, let firstText = texts.first, firstText.mayBeWebURL, let onlyURL = URL(string: firstText) {
            // - an embed -> only 1 link of text, that's it
            // - a link only -> share that instead of the source but with the text
            url = onlyURL
            texts = []
        }
        let text = texts.isEmpty ? nil : texts.joined(separator: .lineSeparator)
        return ReadShareableContent(text: text, url: url, elements: elements)
    }

    @MainActor private func setContentToPasteboard(_ content: ReadShareableContent) {
        imageCancellables.removeAll()
        let pasteboard = pasteboard
        pasteboard.clearContents()

        if let text = content.text ?? content.url?.absoluteString {
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(text, forType: .string)
        }

        // When we have a single image, let's put the file directly in pasteboard
        if content.elements?.count == 1, let element = content.elements?.first, case .image = element.kind {
            if let image = getImageFromElementKind(element.kind) {
                pasteboard.clearContents()
                pasteboard.writeObjects([image])
            } else {
                // We don't have the image in FileDB yet let's wait for the updated element
                let timeout = 5
                let timeoutBlock = DispatchWorkItem {
                    Logger.shared.logInfo("Timeout downloading image for pasteboard", category: .pointAndShoot)
                    self.imageCancellables.removeAll()
                }
                element.$kind.dropFirst().sink { [unowned self] newKind in
                    timeoutBlock.cancel()
                    if let image = self.getImageFromElementKind(newKind) {
                        pasteboard.clearContents()
                        pasteboard.writeObjects([image])
                    }
                    self.imageCancellables.removeAll()
                }.store(in: &imageCancellables)
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(timeout), execute: timeoutBlock)
            }
        }
    }

    private func getImageFromElementKind(_ elementKind: ElementKind) -> NSImage? {
        guard case let .image(imageID, _, _) = elementKind, let htmlNoteAdapter = htmlNoteAdapter,
           let imageRecord = try? htmlNoteAdapter.visitor.fileStorage?.fetch(uid: imageID) else {
            return nil
        }
        return NSImage(data: imageRecord.data)
    }

    @MainActor private func handleURL(_ url: URL) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Workaround to allow using `NSAlert` in a `Task`.
            // See [FB9857161](https://github.com/feedback-assistant/reports/issues/288)
            DispatchQueue.main.async {
                let urlRequest = URLRequest(url: url)
                let deeplinkHandler = ExternalDeeplinkHandler(request: urlRequest)
                if deeplinkHandler.isDeeplink() {
                    if deeplinkHandler.shouldOpenDeeplink() {
                        DispatchQueue.main.async { // fixes the alert stealing the keywindow of the opened app
                            NSWorkspace.shared.open(url)
                        }
                    }
                } else {
                    self.openWebURL(url)
                }
                continuation.resume()
            }
        }

    }
}

class ShareWindowFeatures: WKWindowFeatures {
    private let service: ShareService

    init(for service: ShareService) {
        self.service = service
        super.init()
    }

    override var width: NSNumber? {
        switch service {
        case .reddit:
            return 700
        default:
            return 550
        }
    }
    override var height: NSNumber? {
        switch service {
        case .twitter, .facebook:
            return 350
        case .reddit:
            return 700
        default:
            return 550
        }
    }
    override var allowsResizing: NSNumber? { 1 }
}
