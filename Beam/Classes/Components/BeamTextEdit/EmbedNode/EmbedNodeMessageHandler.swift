//
//  EmbedNodeMessageHandler.swift
//  Beam
//
//  Created by Stef Kors on 29/11/2021.
//

import Foundation
import BeamCore

enum EmbedNodeMessages: String, CaseIterable {
    case EmbedNode_contentSize
}

/**
 Handles logging messages sent from web page's javascript.
 */
class EmbedNodeMessageHandler: BeamMessageHandler<EmbedNodeMessages> {

    init(config: BeamWebViewConfiguration) {
        super.init(config: config, messages: EmbedNodeMessages.self, jsFileName: "EmbedNode_prod", cssFileName: "EmbedNode", jsCodePosition: .atDocumentStart, forMainFrameOnly: true)
    }

    override func onMessage(messageName: String, messageBody: Any?, from: WebPage) {
        guard let messageKey = EmbedNodeMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message '\(messageName)' for logging message handler", category: .web)
            return
        }
        let msgPayload = messageBody as? [String: AnyObject]
        switch messageKey {
        case EmbedNodeMessages.EmbedNode_contentSize:
            guard let dict = msgPayload,
                  let width = dict["width"] as? CGFloat,
                  let height = dict["height"] as? CGFloat else {
                Logger.shared.logError("Ignored embed event: \(String(describing: msgPayload))", category: .embed)
                return
            }

            if let embedPage = from as? EmbedNodeWebPage {
                // Called when the embednode content size updates. Will be called multiple times and possibly when the webview resizes.
                // The call is debounced on the trailing edge from JS side as it's called multiple times while loading the page.
                // Possibly some padding needs to be accounted for.
                embedPage.delegate?.embedNodeDelegateCallback(size: CGSize(width: width + 10, height: height + 5))
            }
        }
    }
}
