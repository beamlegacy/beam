import Foundation
import BeamCore

enum LogMessages: String, CaseIterable {
    case beam_logging
}

/**
 Handles messages sent from web page's javascript.
 */
class LoggingMessageHandler: NSObject, WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let messageBody = message.body as? [String: AnyObject]
        let messageKey = message.name
        let messageName = messageKey // .components(separatedBy: "_beam_")[1]
        switch messageName {
        case LogMessages.beam_logging.rawValue:
            guard let dict = messageBody,
                  let type = dict["type"] as? String,
                  let message = dict["message"] as? String
                    else {
                Logger.shared.logError("Ignored log event: \(String(describing: messageBody))",
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

    func unregister(from webView: WKWebView) {
        LogMessages.allCases.forEach {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: $0.rawValue)
        }
    }

    func register(to webView: WKWebView, page: WebPage) {
        LogMessages.allCases.forEach {
            let handler = $0.rawValue
            webView.configuration.userContentController.add(self, name: handler)
            Logger.shared.logDebug("Added Script handler: \(handler)", category: .web)
        }
        let jsCode = loadFile(from: "OverrideConsole", fileType: "js")
        page.addJS(source: jsCode, when: .atDocumentStart)
    }
}
