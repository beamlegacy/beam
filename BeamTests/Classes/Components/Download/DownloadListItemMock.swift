import Foundation
@testable import Beam

final class DownloadListItemMock {

    var id: Int
    var filename: String?
    var fileExtension: String?
    var artifactURL: URL?

    var state: DownloadListItemState {
        didSet {
            delegate?.downloadItem(self, stateDidChange: state)
        }
    }

    @Published var progressFractionCompleted: Double = 0
    var progressDescription: String?
    var errorMessage: String?

    var progressFractionCompletedPublisher: Published<Double>.Publisher {
        $progressFractionCompleted
    }

    weak var delegate: DownloadItemDelegate?

    init(id: Int, state: DownloadListItemState) {
        self.id = id
        self.state = state
    }

    private(set) var resumeCalls = 0
    private(set) var cancelCalls = 0
    private(set) var restartCalls = 0
    private(set) var deleteArtifactIfNotCompletedCalls = 0

}

// MARK: - DownloadListItem

extension DownloadListItemMock: DownloadListItem {

    func resume() {
        resumeCalls += 1
    }

    func cancel() {
        cancelCalls += 1
    }

    func restart() {
        restartCalls += 1
    }

    func deleteArtifactIfNotCompleted() {
        deleteArtifactIfNotCompletedCalls += 1
    }

    static func == (lhs: DownloadListItemMock, rhs: DownloadListItemMock) -> Bool {
        lhs.id == rhs.id
    }

}

// MARK: - Hashable

extension DownloadListItemMock: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

}
