import Foundation
import BeamCore
import WebKit

private enum NavigationMessages: String, CaseIterable {
    /**
     Either a history.pushState, history.popState or a history.replaceState has been issued.
     */
    case nav_locationChanged
}

class JSNavigationMessageHandler: SimpleBeamMessageHandler {

    init() {
        let messages = NavigationMessages.self.allCases.map { $0.rawValue }
        super.init(messages: messages, jsFileName: "Navigation_prod")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        guard let messageKey = NavigationMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message '\(messageName)' for navigation message handler", category: .web)
            return
        }
        guard let isMainFrame = frameInfo?.isMainFrame else { return }
        let msgPayload = messageBody as? [String: AnyObject]
        switch messageKey {
        /// Is only called when the JS history API registers a change
        case NavigationMessages.nav_locationChanged:
            guard let dict = msgPayload,
                  let href = dict["href"] as? String,
                  let type = dict["type"] as? String
            else {
                Logger.shared.logError("Expected a url in location change message \(String(describing: msgPayload))", category: .web)
                return
            }
            guard var url = URL(string: href) else {
                Logger.shared.logError("\(href) is not a valid URL in navigation message", category: .web)
                return
            }

            if url.host == nil {
                // Sometimes the JS event sends only the url path ("/page/A.html"). WebView most likely have the full url already.
                guard let webViewURL = webPage.webView.url, webViewURL.absoluteString.contains(href) else {
                    Logger.shared.logError("\(href) doesn't have a host and is not a valid URL in navigation message", category: .web)
                    return
                }
                url = webViewURL
            } else if !isMainFrame {
                // We don't want to react to iframes navigations/state change
                guard let webViewURL = webPage.webView.url, webViewURL == url else { return }
            }
            guard let navigationHandler = webPage.webViewNavigationHandler,
                  let jsEvent = WebViewControllerNavigationSource.JavacriptEvent(rawValue: type) else { return }
            navigationHandler.webView(webPage.webView, didFinishNavigationToURL: url, source: .javascript(event: jsEvent))
            webPage.executeJS("dispatchEvent(new Event('beam_historyLoad'))", objectName: nil, frameInfo: frameInfo)
        }
    }
}
