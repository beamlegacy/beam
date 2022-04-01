//
//  WebViewFocusMessageHandler.swift
//  Beam
//
//  Created by Remi Santos on 22/09/2021.
//

import Foundation
import BeamCore

enum WebViewFocusMessages: String, CaseIterable {
    case WebViewFocus_focusChanged
}

class WebViewFocusMessageHandler: SimpleBeamMessageHandler {

    init() {
        let messages = WebViewFocusMessages.self.allCases.map { $0.rawValue }
        super.init(messages: messages, jsFileName: "WebViewFocus_prod")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        guard let receivedMessage = WebViewFocusMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message \(messageName) for WebViewFocus message handler", category: .web)
            return
        }
        Logger.shared.logDebug("Web focus received \(receivedMessage)", category: .web)
    }
}
