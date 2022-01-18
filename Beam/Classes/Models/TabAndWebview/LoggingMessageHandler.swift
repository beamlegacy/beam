import Foundation
import BeamCore

enum LogMessages: String, CaseIterable {
    case beam_logger_log
}

enum LogLevel: String {
    case uncaught
    case error
    case warning
    case debug
    case log
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
        case LogMessages.beam_logger_log:
            guard let dict = msgPayload,
                  let message = dict["message"] as? String,
                  let level = dict["level"] as? String,
                  let category = dict["category"] as? String
            else {
                Logger.shared.logError("Ignored log event: \(String(describing: msgPayload))",
                                       category: .web)
                return
            }
            let logCategory = LogCategory(rawValue: category) ?? LogCategory.javascript
            switch LogLevel(rawValue: level) {
            case .error, .uncaught:
                Logger.shared.logError(message, category: logCategory)
            case .warning:
                Logger.shared.logWarning(message, category: logCategory)
            case .debug:
                Logger.shared.logDebug(message, category: logCategory)
            case .log:
                Logger.shared.logInfo(message, category: logCategory)
            case .none:
                Logger.shared.logInfo(message, category: logCategory)
            }
        }
    }
}
