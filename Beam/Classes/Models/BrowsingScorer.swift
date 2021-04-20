import Foundation
import BeamCore

protocol BrowsingScorer {
    var currentScore: Score { get }
    func updateScore()
    func addTextSelection()
}
