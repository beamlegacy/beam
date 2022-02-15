import Foundation

/// A fake download item for SwiftUI preview purposes.
final class DownloadListItemFake: DownloadListItem, ObservableObject {

    let id = UUID()
    var filename: String?
    var fileExtension: String?
    var artifactURL: URL?
    var state: DownloadListItemState

    @Published var progressFractionCompleted: Double = 0
    var progressFractionCompletedPublisher: Published<Double>.Publisher { $progressFractionCompleted }

    var progressDescription: String?
    var errorMessage: String?

    weak var delegate: DownloadItemDelegate?

    init(
        filename: String,
        fileExtension: String,
        state: DownloadListItemState = .running,
        progressFractionCompleted: Double = 0,
        localizedDescription: String? = nil,
        errorMessage: String? = nil
    ) {
        self.filename = filename
        self.fileExtension = fileExtension
        self.state = state
        self.errorMessage = errorMessage
        self.progressFractionCompleted = progressFractionCompleted
        self.progressDescription = localizedDescription
    }

    func resume() throws {}
    func cancel() {}
    func restart() throws {}
    func deleteArtifactIfNotCompleted() {}

}

extension DownloadListItemFake: Equatable {
    static func == (lhs: DownloadListItemFake, rhs: DownloadListItemFake) -> Bool {
        lhs.id == rhs.id
    }
}

extension DownloadListItemFake: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
