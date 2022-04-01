//
//  __component_name__MessageHandler.swift
//  Beam
//

import Foundation
import BeamCore

enum __component_name__Messages: String, CaseIterable {
    case __component_name___contentSize
}

/**
 Handles logging messages sent from web page's javascript.
 */
class __component_name__MessageHandler: SimpleBeamMessageHandler {

    init() {
        let messages = __component_name__Messages.self.allCases.map { $0.rawValue }
        super.init(messages: messages, jsFileName: "__component_name___prod", cssFileName: "__component_name__", jsCodePosition: .atDocumentStart, forMainFrameOnly: true)
    }

    override func onMessage(messageName: String, messageBody: Any?, from: WebPage, frameInfo: WKFrameInfo?) {
        guard let messageKey = __component_name__Messages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message '\(messageName)' for logging message handler", category: .web)
            return
        }
        let msgPayload = messageBody as? [String: AnyObject]
        switch messageKey {
        case __component_name__Messages.__component_name___contentSize:
            guard let dict = msgPayload,
                  let width = dict["width"] as? CGFloat,
                  !width.isNaN,
                  let height = dict["height"] as? CGFloat,
                  !height.isNaN else {
                Logger.shared.logError("Ignored embed event: \(String(describing: msgPayload))", category: .embed)
                return
            }

            if let embedPage = from as? __component_name__WebPage {
                // Called when the __component_name__ content size updates. Will be called multiple times and possibly when the webview resizes.
                // The call is debounced on the trailing edge from JS side as it's called multiple times while loading the page.
                // Possibly some padding needs to be accounted for.
                embedPage.delegate?.__component_name__DelegateCallback(size: CGSize(width: width, height: height))
            }
        }
    }
}
