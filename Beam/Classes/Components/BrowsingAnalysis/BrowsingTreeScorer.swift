import Foundation
import BeamCore
import Combine

class BrowsingTreeScorer: NSObject, WebPageRelated, BrowsingScorer {
    weak var page: WebPage?

    let browsingTree: BrowsingTree

    var debouncedUpdateScrollingScore = PassthroughSubject<WebFrames.FrameInfo, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(browsingTree: BrowsingTree) {
        self.browsingTree = browsingTree
        super.init()

        debouncedUpdateScrollingScore
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] frame in
                self?.updateScrollingScore(frame)
            }
            .store(in: &cancellables)
    }

    var currentScore: Score { browsingTree.current.score }

    func scoreApply(changes: (UrlScoreProtocol) -> Void) {
        browsingTree.current.scoreApply(changes: changes)
    }
    func updateScore() {
        let score = browsingTree.current.score.score
        self.page?.score = score
    }

    func addTextSelection() {
        currentScore.textSelections += 1
        scoreApply {$0.textSelections += 1}
        updateScore()
    }

    /// Update the score with scroll information of the current webpage frame
    /// - Parameter frame: Frame infomation
    func updateScrollingScore(_ frame: WebFrames.FrameInfo) {
        if frame.width > 0, frame.height > 0 {

            let currentScrollRatioX = frame.scrollX.isNaN ? 0 : Float(frame.scrollX / frame.width)
            let currentScrollRatioY = frame.scrollY.isNaN ? 0 : Float(frame.scrollY / frame.height)
            let currentArea = Float(frame.width * frame.height)

            currentScore.scrollRatioX = max(currentScrollRatioX, currentScore.scrollRatioX)
            currentScore.scrollRatioY = max(currentScrollRatioY, currentScore.scrollRatioY)
            currentScore.area = currentArea

            scoreApply {
                $0.area = currentArea
                $0.scrollRatioX = max(currentScrollRatioX, $0.scrollRatioX)
                $0.scrollRatioY = max(currentScrollRatioY, $0.scrollRatioY)
            }
            updateScore()
        }
    }
}
