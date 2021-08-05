import Foundation
import BeamCore

enum NavigationMessages: String, CaseIterable {
    /**
     Either a history.pushState or a history.replaceState has been issued.
     */
    case nav_locationChanged
}

class WebNavigationMessageHandler: BeamMessageHandler<NavigationMessages> {

    init(config: BeamWebViewConfiguration) {
        super.init(config: config, messages: NavigationMessages.self, jsFileName: "Navigation")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage) {
        guard let messageKey = NavigationMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message '\(messageName)' for navigation message handler", category: .web)
            return
        }
        let msgPayload = messageBody as? [String: AnyObject]
        switch messageKey {
        /// Is only called when the JS history API registers a change
        case NavigationMessages.nav_locationChanged:
            guard let dict = msgPayload,
                  let urlString = dict["url"] as? String,
                  let type = dict["type"] as? String,
                  let href = dict["href"] as? String
                else {
                Logger.shared.logError("Expected a url in location change message \(String(describing: msgPayload))", category: .web)
                return
            }
            guard urlString != webPage.url?.absoluteString else {
                Logger.shared.logDebug("Location change event url isn't different from current webPage url", category: .web)
                return
            }
            guard href == webPage.url?.absoluteString else {
                Logger.shared.logWarning("Location changed but in \(href) which is different from main frame \(String(describing: webPage.url))", category: .web)
                return
            }
            guard let url = URL(string: urlString) else {
                Logger.shared.logError("\(urlString) is not a valid URL in navigation message", category: .web)
                return
            }
            guard let navigationController = webPage.navigationController else { return }
            let replace: Bool = type == "replaceState" ? true : false
            navigationController.navigatedTo(url: url, webView: webPage.webView, replace: replace)
            _ = webPage.executeJS("dispatchEvent(new Event('beam_historyLoad'))", objectName: nil)
        }
    }
}
