//
//  ContextMenuMessageHandler.swift
//  Beam
//
//  Created by Adam Viaud on 01/06/2022.
//

import BeamCore
import UniformTypeIdentifiers

/// Payload of an invocation of the context menu in the web view.
enum ContextMenuMessageHandlerPayload {

    /// Menu invoked from the web page with no particular content.
    case page(href: String)

    /// Menu invoked from a text selection.
    case textSelection(contents: String)

    /// Menu invoked from a link.
    case link(href: String)

    /// Menu invoked from an image, inline or raw.
    case image(src: String)

    /// Menu invoked from an image contained within a link.
    case linkPlusImage(href: String, src: String)

}

extension ContextMenuMessageHandlerPayload {

    var linkHrefURL: URL? {
        switch self {
        case .page(let href), .link(let href), .linkPlusImage(let href, _):
            return URL(string: href)
        default:
            return nil
        }
    }

    var imageSrcURL: URL? {
        switch self {
        case .image(let src), .linkPlusImage(_, let src):
            return URL(string: src)
        default:
            return nil
        }
    }

    var base64: (data: Data, mimeType: String)? {
        switch self {
        case .image(let src), .linkPlusImage(_, let src):
            let array = src.split(separator: ",").map(String.init)
            guard array.count == 2, let base64 = Data(base64Encoded: array[1]) else {
                return nil
            }
            var mimeType = array[0].replacingOccurrences(of: "data:", with: "", options: [.anchored])
            mimeType = mimeType.replacingOccurrences(of: ";base64", with: "")
            return (base64, mimeType)
        default:
            return nil
        }
    }

}

/// Message handler used to manage context menus apparitions and items in the web page.
final class ContextMenuMessageHandler: SimpleBeamMessageHandler {

    private enum Messages: String, CaseIterable {
        case ContextMenu_menuInvoked
    }

    init() {
        let messages = Messages.self.allCases.map { $0.rawValue }
        super.init(messages: messages, jsFileName: "ContextMenu_prod")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        guard let message = Messages(rawValue: messageName), case .ContextMenu_menuInvoked = message else {
            Logger.shared.logError("Unsupported message \(messageName) for ContextMenuMessages message handler", category: .web)
            return
        }

        guard let messageBody = messageBody else {
            Logger.shared.logError("Missing body in ContextMenuMessageHandler message handler", category: .web)
            return
        }

        do {
            let payload = try ContextMenuMessageHandlerPayload(from: messageBody)
            webPage.pendingContextMenuPayload = payload
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .web)
        }
    }

}

extension ContextMenuMessageHandlerPayload: ScriptMessageBodyDecodable {

    private enum ContextMenuMessageHandlerInvocation: Int {
        case page
        case textSelection
        case link
        case image
        case linkPlusImage
    }

    init(from scriptMessageBody: Any) throws {
        guard
            let dictionary = scriptMessageBody as? [String: Any],
            let params = dictionary[CodingKeys.parameters.rawValue] as? [String: Any],
            let rawInvocation = dictionary[CodingKeys.invocation.rawValue] as? Int,
            let invocation = ContextMenuMessageHandlerInvocation(rawValue: rawInvocation)
        else {
            throw ScriptMessageBodyDecodingError.unexpectedFormat
        }

        func getValue(for key: CodingKeys, in container: [String: Any]) throws -> String {
            guard let contents = container[key.rawValue] as? String else {
                throw ScriptMessageBodyDecodingError.unexpectedFormat
            }
            return contents
        }

        switch invocation {
        case .page:
            self = .page(href: try getValue(for: .href, in: dictionary))
        case .textSelection:
            self = .textSelection(contents: try getValue(for: .contents, in: params))
        case .link:
            self = .link(href: try getValue(for: .href, in: params))
        case .image:
            self = .image(src: try getValue(for: .src, in: params))
        case .linkPlusImage:
            self = .linkPlusImage(href: try getValue(for: .href, in: params), src: try getValue(for: .src, in: params))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case invocation, parameters, href, contents, src
    }

}
