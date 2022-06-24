//
//  ContextMenuMessageHandler.swift
//  Beam
//
//  Created by Adam Viaud on 01/06/2022.
//

import BeamCore
import UniformTypeIdentifiers

/// Payload of an invocation of the context menu in the web view.
indirect enum ContextMenuMessageHandlerPayload {

    /// Menu invoked from the web page with no particular content.
    case page(href: String)

    /// Menu invoked from a text selection.
    case textSelection(contents: String)

    /// Menu invoked from a link.
    case link(href: String)

    /// Menu invoked from an image, inline or raw.
    case image(src: String)

    /// Menu invoked from a combination of invocations.
    case multiple(items: [ContextMenuMessageHandlerPayload])

}

extension ContextMenuMessageHandlerPayload {

    var contents: String? {
        switch self {
        case .textSelection(let contents):
            return contents
        case .multiple(let items):
            return items.compactMap(\.contents).first
        default:
            return nil
        }
    }

    var linkHrefURL: URL? {
        switch self {
        case .page(let href), .link(let href):
            return URL(string: href)
        case .multiple(let items):
            return items.compactMap(\.linkHrefURL).first
        default:
            return nil
        }
    }

    var imageSrcURL: URL? {
        switch self {
        case .image(let src):
            return URL(string: src)
        case .multiple(let items):
            return items.compactMap(\.imageSrcURL).first
        default:
            return nil
        }
    }

    var base64: (data: Data, mimeType: String)? {
        switch self {
        case .image(let src):
            let array = src.split(separator: ",").map(String.init)
            guard array.count == 2, let base64 = Data(base64Encoded: array[1]) else {
                return nil
            }
            var mimeType = array[0].replacingOccurrences(of: "data:", with: "", options: [.anchored])
            mimeType = mimeType.replacingOccurrences(of: ";base64", with: "")
            return (base64, mimeType)
        case .multiple(let items):
            return items.compactMap(\.base64).first
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

    private struct Invocations: OptionSet {

        let rawValue: Int

        static let page             = Invocations(rawValue: 1 << 0)
        static let textSelection    = Invocations(rawValue: 1 << 1)
        static let link             = Invocations(rawValue: 1 << 2)
        static let image            = Invocations(rawValue: 1 << 3)

    }

    init(from scriptMessageBody: Any) throws {
        guard
            let dictionary = scriptMessageBody as? [String: Any],
            let params = dictionary[CodingKeys.parameters.rawValue] as? [String: Any],
            let rawInvocations = dictionary[CodingKeys.invocations.rawValue] as? Int
        else {
            throw ScriptMessageBodyDecodingError.unexpectedFormat
        }

        func getValue(for key: CodingKeys, in container: [String: Any]) throws -> String {
            guard let contents = container[key.rawValue] as? String else {
                throw ScriptMessageBodyDecodingError.unexpectedFormat
            }
            return contents
        }

        var invocations = Invocations(rawValue: rawInvocations)

        if invocations.contains(.page) {
            // pop-count check to be sure that the page invocation is not associated with other invocations
            guard invocations.rawValue.nonzeroBitCount == 1 else {
                throw ScriptMessageBodyDecodingError.unexpectedFormat
            }

            self = .page(href: try getValue(for: .href, in: dictionary))
        } else {
            // there may be multiple invocations so let's accumulate them
            var items: [ContextMenuMessageHandlerPayload] = []

            if invocations.contains(.textSelection) {
                items.append(.textSelection(contents: try getValue(for: .contents, in: params)))
                invocations.subtract(.textSelection)
            }
            if invocations.contains(.link) {
                items.append(.link(href: try getValue(for: .href, in: params)))
                invocations.subtract(.link)
            }
            if invocations.contains(.image) {
                items.append(.image(src: try getValue(for: .src, in: params)))
                invocations.subtract(.image)
            }

            // making sure we consumed everything
            guard invocations.isEmpty, !items.isEmpty else {
                throw ScriptMessageBodyDecodingError.unexpectedFormat
            }

            if items.count == 1 {
                self = items[0]
            } else {
                self = .multiple(items: items)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case invocations, parameters, href, contents, src
    }

}
