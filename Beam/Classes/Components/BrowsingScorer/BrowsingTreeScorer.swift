import Foundation
import BeamCore

class BrowsingTreeScorer: WebPageHolder, BrowsingScorer {

    let browsingTree: BrowsingTree

    init(browsingTree: BrowsingTree) {
        self.browsingTree = browsingTree
    }

    var currentScore: Score { browsingTree.current.score }

    func updateScore() {
        let score = browsingTree.current.score.score
//      Logger.shared.logDebug("updated score[\(url!.absoluteString)] = \(s)", category: .general)
        page.score = score
        if score > 0.0 {    // Automatically add current page to note over a certain threshold
            _ = page.addToNote(allowSearchResult: false) as? Scorable
        }
    }

    func addTextSelection() {
        browsingTree.current.score.textSelections += 1
        updateScore()
    }
}
