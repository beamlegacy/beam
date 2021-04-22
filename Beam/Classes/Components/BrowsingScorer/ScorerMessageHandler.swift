import Foundation
import BeamCore

private enum ScorerMessages: String, CaseIterable {
    case score_scroll
}

/**
 Handles messages sent from web page's javascript.
 */
class ScorerMessageHandler: NSObject, WKScriptMessageHandler {

    var browsingScorer: BrowsingScorer

    init(browsingScorer: BrowsingScorer) {
        self.browsingScorer = browsingScorer
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let messageBody = message.body as? [String: AnyObject]
        let messageKey = message.name
        let messageName = messageKey // .components(separatedBy: "_beam_")[1]
        switch messageName {

        case ScorerMessages.score_scroll.rawValue:
            guard let dict = messageBody,
                  let x = dict["x"] as? CGFloat,
                  let y = dict["y"] as? CGFloat,
                  let width = dict["width"] as? CGFloat,
                  let height = dict["height"] as? CGFloat,
                  let scale = dict["scale"] as? CGFloat
                    else {
                Logger.shared.logError("Scorer ignored scroll event: \(String(describing: messageBody))", category: .web)
                return
            }
            if width > 0, height > 0 {
                let currentScore = browsingScorer.currentScore
                currentScore.scrollRatioX = max(Float(x / width), currentScore.scrollRatioX)
                currentScore.scrollRatioY = max(Float(y / height), currentScore.scrollRatioY)
                currentScore.area = Float(width * height)
                browsingScorer.updateScore()
            }
            Logger.shared.logDebug("Scorer handled scroll: \(x), \(y)", category: .web)

        default:
            break
        }
    }

    func register(to webView: WKWebView, page: WebPage) {
        ScorerMessages.allCases.forEach {
            let handler = $0.rawValue
            webView.configuration.userContentController.add(self, name: handler)
            Logger.shared.logDebug("Added scorer script handler: \(handler)", category: .web)
        }
        injectScripts(into: page)
    }

    private func injectScripts(into page: WebPage) {
        var jsCode = loadFile(from: "Scorer", fileType: "js")
        page.addJS(source: jsCode, when: .atDocumentEnd)
    }

    func unregister(from webView: WKWebView) {
        ScorerMessages.allCases.forEach {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: $0.rawValue)
        }
    }

    func destroy(for webView: WKWebView) {
        self.unregister(from: webView)
    }
}
