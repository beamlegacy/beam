import Foundation
import BeamCore
import Combine

protocol BrowsingScorer: WebPageRelated {
    var debouncedUpdateScrollingScore: PassthroughSubject<WebFrames.FrameInfo, Never> { get }
    var currentScore: Score { get }
    func updateScore()
    func addTextSelection()
    func scoreApply(changes: @escaping (UrlScoreProtocol) -> Void)
    func updateScrollingScore(_ frame: WebFrames.FrameInfo)
}
