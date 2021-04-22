import Foundation
import BeamCore

private enum PasswordMessages: String, CaseIterable {
    case password_textInputFields
    case password_textInputFocusIn
    case password_textInputFocusOut
    case password_formSubmit
    case password_scroll
    case password_resize
}

/**
 Handles messages sent from web page's javascript.
 */
class PasswordMessageHandler: NSObject, WKScriptMessageHandler {

    var passwordOverlayController: PasswordOverlayController

    init(passwordOverlayController: PasswordOverlayController) {
        self.passwordOverlayController = passwordOverlayController
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let messageBody = message.body as? [String: AnyObject]
        let messageKey = message.name
        let messageName = messageKey // .components(separatedBy: "_beam_")[1]
        switch messageName {

        case PasswordMessages.password_textInputFields.rawValue:
            guard let jsonString = message.body as? String else { break }
            passwordOverlayController.updateInputFields(with: jsonString)

        case PasswordMessages.password_textInputFocusIn.rawValue:
            guard let elementId = message.body as? String else { break }
            passwordOverlayController.updateInputFocus(for: elementId, becomingActive: true)

        case PasswordMessages.password_textInputFocusOut.rawValue:
            guard let elementId = message.body as? String else { break }
            passwordOverlayController.updateInputFocus(for: elementId, becomingActive: false)

        case PasswordMessages.password_formSubmit.rawValue:
            passwordOverlayController.handleWebFormSubmit()

        case PasswordMessages.password_scroll.rawValue:
            guard let dict = messageBody,
                  let x = dict["x"] as? CGFloat,
                  let y = dict["y"] as? CGFloat,
                  let width = dict["width"] as? CGFloat,
                  let height = dict["height"] as? CGFloat,
                  let scale = dict["scale"] as? CGFloat
                    else {
                Logger.shared.logError("Ignored scroll event: \(String(describing: messageBody))", category: .web)
                return
            }
            passwordOverlayController.updateScrollPosition(x: x, y: y, width: width, height: height)
            Logger.shared.logDebug("Password controller handled scroll: \(x), \(y)", category: .web)

        case PasswordMessages.password_resize.rawValue:
            guard let dict = messageBody,
                  let width = dict["width"] as? CGFloat,
                  let height = dict["height"] as? CGFloat,
                  let origin = dict["origin"] as? String
                    else {
                Logger.shared.logError("Password controller ignored resize: \(String(describing: messageBody))", category: .web)
                return
            }
            passwordOverlayController.updateViewSize(width: width, height: height)

        default:
            break
        }
    }

    func register(to webView: WKWebView, page: WebPage) {
        PasswordMessages.allCases.forEach {
            let handler = $0.rawValue
            webView.configuration.userContentController.add(self, name: handler)
            Logger.shared.logDebug("Added password script handler: \(handler)", category: .web)
        }
        injectScripts(into: page)
    }

    private func injectScripts(into page: WebPage) {
        var jsCode = loadFile(from: "PasswordManager", fileType: "js")
        page.addJS(source: jsCode, when: .atDocumentEnd)
    }

    func unregister(from webView: WKWebView) {
        PasswordMessages.allCases.forEach {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: $0.rawValue)
        }
    }

    func destroy(for webView: WKWebView) {
        self.unregister(from: webView)
    }
}
