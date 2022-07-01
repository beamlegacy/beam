import Foundation
import BeamCore
import SwiftUI

enum MouseOverAndSelectionMessage: String, CaseIterable {

    case MouseOverAndSelection_linkMouseOver
    case MouseOverAndSelection_linkMouseOut
    case MouseOverAndSelection_selectionChange
    case MouseOverAndSelection_selectionAndShortcutHit

}

/// A message handler receiving mouse hovering location updates when hovering over and out web links and also listening for text selection changes.
final class MouseOverAndSelectionMessageHandler: SimpleBeamMessageHandler {

    init() {
        let messages = MouseOverAndSelectionMessage.self.allCases.map { $0.rawValue }
        super.init(messages: messages, jsFileName: "MouseOverAndSelection_prod")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        guard let messageKey = MouseOverAndSelectionMessage(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message '\(messageName)' for MouseOverLink message handler", category: .web)
            return
        }

        switch messageKey {
        case .MouseOverAndSelection_linkMouseOver:
            guard let messageBody = messageBody else {
                Logger.shared.logError("Missing body in MouseOverAndSelection message handler", category: .web)
                break
            }

            do {
                let linkMouseOver = try LinkMouseOver(from: messageBody)
                webPage.mouseHoveringLocation = .link(
                    url: linkMouseOver.url,
                    opensInNewTab: linkMouseOver.opensInNewTab
                )
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .web)
            }

        case .MouseOverAndSelection_linkMouseOut:
            webPage.mouseHoveringLocation = .none

        case .MouseOverAndSelection_selectionChange, .MouseOverAndSelection_selectionAndShortcutHit:
            guard let messageBody = messageBody else {
                Logger.shared.logError("Missing body in MouseOverAndSelection message handler", category: .web)
                break
            }
            do {
                let textSelection = try TextSelection(from: messageBody)
                webPage.textSelection = textSelection.selection

                if case .MouseOverAndSelection_selectionAndShortcutHit = messageKey {
                    webPage.quickSearchQueryWithSelection()
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .web)
            }
        }
    }

}

private struct LinkMouseOver {
    let url: URL
    let target: String?

    var opensInNewTab: Bool { target == "_blank" }
}

extension LinkMouseOver: ScriptMessageBodyDecodable {

    init(from scriptMessageBody: Any) throws {
        guard
            let dictionary = scriptMessageBody as? [String: Any],
            let urlAsString = dictionary[CodingKeys.url.rawValue] as? String,
            let url = URL(string: urlAsString),
            let target = dictionary[CodingKeys.target.rawValue] as? String? else {
                throw ScriptMessageBodyDecodingError.unexpectedFormat
            }

        self.url = url
        self.target = target
    }

    private enum CodingKeys: String, CodingKey {
        case url, target
    }

}

private struct TextSelection {
    let selection: String
}

extension TextSelection: ScriptMessageBodyDecodable {

    init(from scriptMessageBody: Any) throws {
        guard
            let dictionary = scriptMessageBody as? [String: Any],
            let textSelection = dictionary[CodingKeys.selection.rawValue] as? String else {
                throw ScriptMessageBodyDecodingError.unexpectedFormat
            }

        self.selection = textSelection
    }

    private enum CodingKeys: String, CodingKey {
        case selection
    }

}
