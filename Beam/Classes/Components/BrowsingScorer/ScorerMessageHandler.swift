import Foundation
import BeamCore

enum ScorerMessages: String, CaseIterable {
    case score_scroll
}

/**
 Handles browsing scoring messages sent from web page's javascript.
 */
class ScorerMessageHandler: BeamMessageHandler<ScorerMessages> {

    init(page: BeamWebViewConfiguration) {
        super.init(config: page, messages: ScorerMessages.self, jsFileName: "Scorer")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage) {
        guard let messageKey = ScorerMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message \(messageName) for scorer message handler", category: .web)
            return
        }
        let scorerBody = messageBody as? [String: AnyObject]
        switch messageKey {
        case ScorerMessages.score_scroll:
            guard let dict = scorerBody,
                  let x = dict["x"] as? CGFloat,
                  let y = dict["y"] as? CGFloat,
                  let width = dict["width"] as? CGFloat,
                  let height = dict["height"] as? CGFloat,
                  dict["scale"] as? CGFloat != nil
                    else {
                Logger.shared.logError("Scorer ignored scroll event: \(String(describing: messageBody))", category: .web)
                return
            }
            if width > 0, height > 0 {
                let currentScore = webPage.browsingScorer.currentScore
                currentScore.scrollRatioX = max(Float(x / width), currentScore.scrollRatioX)
                currentScore.scrollRatioY = max(Float(y / height), currentScore.scrollRatioY)
                currentScore.area = Float(width * height)
                webPage.browsingScorer.updateScore()
            }
            Logger.shared.logDebug("Scorer handled scroll: \(x), \(y)", category: .web)
        }
    }
}
