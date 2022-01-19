import Foundation
import BeamCore

/**
 Handles messages sent from web page's javascript.
 */
class BeamMessageHandler<T: RawRepresentable & CaseIterable> : NSObject, WKScriptMessageHandler where T.RawValue == String {

    let config: BeamWebViewConfiguration
    let messages: T.Type
    let jsFileName: String
    let cssFileName: String?
    let jsCodePosition: WKUserScriptInjectionTime
    let forMainFrameOnly: Bool

    init(config: BeamWebViewConfiguration, messages: T.Type, jsFileName: String, cssFileName: String? = nil, jsCodePosition: WKUserScriptInjectionTime = .atDocumentEnd, forMainFrameOnly: Bool = false) {
        self.config = config
        self.messages = messages
        self.jsFileName = jsFileName
        self.cssFileName = cssFileName
        self.jsCodePosition = jsCodePosition
        self.forMainFrameOnly = forMainFrameOnly
    }

    func register(to config: WKWebViewConfiguration) {
        messages.allCases.forEach {
            let message = $0.rawValue
            config.userContentController.add(self, name: message)
            Logger.shared.logDebug("Added Script handler: \(message)", category: .web)
        }
        injectScripts()
    }

    private func injectScripts() {
        if let cssFileName = cssFileName,
           let cssCode = loadFile(from: cssFileName, fileType: "css") {
            config.addCSS(source: cssCode, when: .atDocumentEnd)
        }

        if let jsCode = loadFile(from: jsFileName, fileType: "js") {
            config.addJS(source: jsCode, when: jsCodePosition, forMainFrameOnly: forMainFrameOnly)
        }
    }

    func unregister(from webView: WKWebView) {
        let configuration = webView.configurationWithoutMakingCopy
        messages.allCases.forEach {
            configuration.userContentController.removeScriptMessageHandler(forName: $0.rawValue)
        }
    }

    func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        fatalError("onMessage must be overridden in subclass")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let webView = message.webView else {
            Logger.shared.logError("WebView is nil on received WKScriptMessage", category: .web)
            return
        }
        guard let beamWebView = webView as? BeamWebView else {
            // Failing this type cast during a "Sign in with Apple" flow is most likely due to the creation of a "SecretWebView"
            // https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/Cocoa/SOAuthorization/PopUpSOAuthorizationSession.mm#L193
            Logger.shared.logError("WebView cannot be cast to BeamWebView type || \(self.jsFileName) || message \(message.name) \(message.body)", category: .web)
            return
        }
        guard let beamWebPage = beamWebView.page else {
            Logger.shared.logError("WebView doesn't include a WebPage", category: .web)
            return
        }

        onMessage(messageName: message.name, messageBody: message.body, from: beamWebPage, frameInfo: message.frameInfo)
    }

    func destroy(for webView: WKWebView) {
        unregister(from: webView)
    }
}
