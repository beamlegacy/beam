import Foundation
import BeamCore

class BrowsingTreeScorer: WebPageHolder, BrowsingScorer {

    let browsingTree: BrowsingTree

    init(browsingTree: BrowsingTree) {
        self.browsingTree = browsingTree
    }

    var currentScore: Score { browsingTree.current.score }

    func applyLongTermScore(changes: (LongTermUrlScore) -> Void) {
        browsingTree.current.longTermScoreApply(changes: changes)
    }
    func updateScore() {
        let score = browsingTree.current.score.score
        page.score = score
    }

    func addTextSelection() {
        currentScore.textSelections += 1
        applyLongTermScore {$0.textSelections += 1}
        updateScore()
    }
}
