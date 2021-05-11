import Foundation
import BeamCore

enum LogMessages: String, CaseIterable {
    case beam_logging
}

/**
 Handles logging messages sent from web page's javascript.
 */
class LoggingMessageHandler: BeamMessageHandler<LogMessages> {

    init(page: BeamWebViewConfiguration) {
        super.init(config: page, messages: LogMessages.self, jsFileName: "OverrideConsole", jsCodePosition: .atDocumentStart)
    }

    override func onMessage(messageName: String, messageBody: Any?, from: WebPage) {
        let loggingBody = messageBody as? [String: AnyObject]
        switch messageName {
        case LogMessages.beam_logging.rawValue:
            guard let dict = loggingBody,
                  let type = dict["type"] as? String,
                  let message = dict["message"] as? String
                    else {
                Logger.shared.logError("Ignored log event: \(String(describing: loggingBody))",
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

        default:
            break
        }
    }
}
