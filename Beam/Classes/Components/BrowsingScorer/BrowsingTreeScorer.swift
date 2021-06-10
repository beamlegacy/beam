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
        page.score = score
    }

    func addTextSelection() {
        browsingTree.current.score.textSelections += 1
        updateScore()
    }
}
