import Foundation
import BeamCore

enum LogMessages: String, CaseIterable {
    case beam_logging
}

/**
 Handles logging messages sent from web page's javascript.
 */
class LoggingMessageHandler: BeamMessageHandler<LogMessages> {

    init(config: BeamWebViewConfiguration) {
        super.init(config: config, messages: LogMessages.self, jsFileName: "OverrideConsole", jsCodePosition: .atDocumentStart)
    }

    override func onMessage(messageName: String, messageBody: Any?, from: WebPage, frameInfo: WKFrameInfo?) {
        guard let messageKey = LogMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message '\(messageName)' for logging message handler", category: .web)
            return
        }
        let msgPayload = messageBody as? [String: AnyObject]
        switch messageKey {
        case LogMessages.beam_logging:
            guard let dict = msgPayload,
                  let type = dict["type"] as? String,
                  let message = dict["message"] as? String
                    else {
                Logger.shared.logError("Ignored log event: \(String(describing: msgPayload))",
                                       category: .web)
                return
            }
            if type == "error" {
                Logger.shared.logError(message, category: .javascript)
            } else if type == "warning" {
                Logger.shared.logWarning(message, category: .javascript)
            } else if type == "log" {
                Logger.shared.logInfo(message, category: .javascript)
            }
        }
    }
}
