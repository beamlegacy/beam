import Foundation
import BeamCore

enum ScorerMessages: String, CaseIterable {
    case score_scroll
}

/**
 Handles browsing scoring messages sent from web page's javascript.
 */
class ScorerMessageHandler: BeamMessageHandler<ScorerMessages> {

    init(config: BeamWebViewConfiguration) {
        super.init(config: config, messages: ScorerMessages.self, jsFileName: "Scorer")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage) {
        guard let messageKey = ScorerMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message \(messageName) for scorer message handler", category: .web)
            return
        }
        guard let browsingScorer = webPage.browsingScorer else { return }
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
                let currentScore = browsingScorer.currentScore
                let currentScrollRatioX = Float(x / width)
                currentScore.scrollRatioX = max(currentScrollRatioX, currentScore.scrollRatioX)
                browsingScorer.applyLongTermScore {$0.scrollRatioX = max(currentScrollRatioX, $0.scrollRatioX)}

                let currentScrollRatioY = Float(y / height)
                currentScore.scrollRatioY = max(currentScrollRatioY, currentScore.scrollRatioY)
                browsingScorer.applyLongTermScore {$0.scrollRatioY = max(currentScrollRatioY, $0.scrollRatioY)}

                let currentArea = Float(width * height)
                currentScore.area = currentArea
                browsingScorer.applyLongTermScore {$0.area = currentArea}

                browsingScorer.updateScore()
            }
            Logger.shared.logDebug("Scorer handled scroll: \(x), \(y)", category: .web)
        }
    }
}
