import Foundation
import BeamCore
import SwiftUI

enum LinkMouseOverMessage: String, CaseIterable {

    case linkMouseOver
    case linkMouseOut

}

/// A message handler receiving mouse hovering location updates when hovering over and out web links.
final class LinkMouseOverMessageHandler: SimpleBeamMessageHandler {

    init() {
        let messages = LinkMouseOverMessage.self.allCases.map { $0.rawValue }
        super.init(messages: messages, jsFileName: "LinkMouseOver")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        guard let messageKey = LinkMouseOverMessage(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message '\(messageName)' for MouseOverLink message handler", category: .web)
            return
        }

        switch messageKey {
        case .linkMouseOver:
            guard let messageBody = messageBody else {
                Logger.shared.logError("Missing body in LinkMouseOver message handler", category: .web)
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

        case .linkMouseOut:
            webPage.mouseHoveringLocation = .none
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
