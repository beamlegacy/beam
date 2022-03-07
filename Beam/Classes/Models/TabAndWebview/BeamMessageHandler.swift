import Foundation
import BeamCore

/**
 Handles messages sent from web page's javascript.
 */
class SimpleBeamMessageHandler: NSObject, WKScriptMessageHandler {
    internal init(
        messages: [String],
        jsFileName: String,
        cssFileName: String? = nil,
        jsCodePosition: WKUserScriptInjectionTime = .atDocumentEnd,
        forMainFrameOnly: Bool = false
    ) {
        self.messages = messages
        self.jsFileName = jsFileName
        self.cssFileName = cssFileName
        self.jsCodePosition = jsCodePosition
        self.forMainFrameOnly = forMainFrameOnly
    }

    let messages: [String]
    let jsFileName: String
    let cssFileName: String?
    let jsCodePosition: WKUserScriptInjectionTime
    let forMainFrameOnly: Bool

    func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        fatalError("onMessage must be overridden in subclass")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let webView = message.webView else {
            Logger.shared.logError("Expected to have webview on message", category: .web)
            return
        }

        guard let beamWebView = webView as? BeamWebView else {
            Logger.shared.logError("Expected to cast", category: .web)
            return
        }

        guard let beamWebPage = beamWebView.page else {
            // Failing to case type to BeamWebView during a "Sign in with Apple" flow is most likely due to the creation of a "SecretWebView"
            // https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/Cocoa/SOAuthorization/PopUpSOAuthorizationSession.mm#L193
            Logger.shared.logError("Expected WebView before receiving WKScriptMessages", category: .web)
            return
        }
        onMessage(messageName: message.name, messageBody: message.body, from: beamWebPage, frameInfo: message.frameInfo)
    }
}
