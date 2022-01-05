import Foundation
import BeamCore
import Combine

class BrowsingTreeScorer: NSObject, WebPageRelated, BrowsingScorer {
    weak var page: WebPage?

    let browsingTree: BrowsingTree

    var debouncedUpdateScrollingScore = PassthroughSubject<WebPositions.FrameInfo, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(browsingTree: BrowsingTree) {
        self.browsingTree = browsingTree
        super.init()

        debouncedUpdateScrollingScore
            .debounce(for: .seconds(200), scheduler: RunLoop.main)
            .sink { [weak self] frame in
                self?.updateScrollingScore(frame)
            }
            .store(in: &cancellables)
    }

    var currentScore: Score { browsingTree.current.score }

    func applyLongTermScore(changes: (LongTermUrlScore) -> Void) {
        browsingTree.current.longTermScoreApply(changes: changes)
    }
    func updateScore() {
        let score = browsingTree.current.score.score
        self.page?.score = score
    }

    func addTextSelection() {
        currentScore.textSelections += 1
        applyLongTermScore {$0.textSelections += 1}
        updateScore()
    }

    /// Update the score with scroll information of the current webpage frame
    /// - Parameter frame: Frame infomation
    func updateScrollingScore(_ frame: WebPositions.FrameInfo) {
        if frame.width > 0, frame.height > 0 {
            let currentScrollRatioX = Float(frame.scrollX / frame.width)
            currentScore.scrollRatioX = max(currentScrollRatioX, currentScore.scrollRatioX)
            applyLongTermScore {$0.scrollRatioX = max(currentScrollRatioX, $0.scrollRatioX)}

            let currentScrollRatioY = Float(frame.scrollY / frame.height)
            currentScore.scrollRatioY = max(currentScrollRatioY, currentScore.scrollRatioY)
            applyLongTermScore {$0.scrollRatioY = max(currentScrollRatioY, $0.scrollRatioY)}

            let currentArea = Float(frame.width * frame.height)
            currentScore.area = currentArea
            applyLongTermScore {$0.area = currentArea}

            updateScore()
        }
    }
}
