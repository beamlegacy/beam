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

    init(config: BeamWebViewConfiguration, messages: T.Type, jsFileName: String, cssFileName: String? = nil, jsCodePosition: WKUserScriptInjectionTime = .atDocumentEnd) {
        self.config = config
        self.messages = messages
        self.jsFileName = jsFileName
        self.cssFileName = cssFileName
        self.jsCodePosition = jsCodePosition
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
        if cssFileName != nil {
            let cssCode = loadFile(from: cssFileName!, fileType: "css")
            config.addCSS(source: cssCode, when: .atDocumentEnd)
        }
        let jsCode = loadFile(from: jsFileName, fileType: "js")
        config.addJS(source: jsCode, when: jsCodePosition)
    }

    func unregister(from webView: WKWebView) {
        let configuration = webView.configurationWithoutMakingCopy
        messages.allCases.forEach {
            configuration.userContentController.removeScriptMessageHandler(forName: $0.rawValue)
        }
    }

    func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage) {
        fatalError("onMessage must be overridden in subclass")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let webView = message.webView as? BeamWebView else {
            fatalError("WebView is not a BeamWebview")
        }
        guard let webPage = webView.page else {
            return
        }

        onMessage(messageName: message.name, messageBody: message.body, from: webPage)
    }

    func destroy(for webView: WKWebView) {
        unregister(from: webView)
    }
}
