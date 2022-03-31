import Foundation
import BeamCore
import Combine

protocol BrowsingScorer: WebPageRelated {
    var debouncedUpdateScrollingScore: PassthroughSubject<WebPositions.FrameInfo, Never> { get }
    var currentScore: Score { get }
    func updateScore()
    func addTextSelection()
    func scoreApply(changes: (UrlScoreProtocol) -> Void)
    func updateScrollingScore(_ frame: WebPositions.FrameInfo)
}
