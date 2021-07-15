import Foundation
import BeamCore

protocol BrowsingScorer: WebPageRelated {
    var currentScore: Score { get }
    func updateScore()
    func addTextSelection()
    func applyLongTermScore(changes: (LongTermUrlScore) -> Void)
}
