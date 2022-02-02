import Foundation

protocol DownloadListItem: ObservableObject, Identifiable, Hashable {

    typealias Delegate = DownloadItemDelegate

    var id: Self.ID { get }
    var filename: String? { get }
    var fileExtension: String? { get }
    var artifactURL: URL? { get }
    var state: DownloadListItemState { get }
    var progressFractionCompleted: Double { get }
    var progressFractionCompletedPublisher: Published<Double>.Publisher { get }
    var progressDescription: String? { get }
    var errorMessage: String? { get }

    var delegate: Delegate? { get set }

    func resume() throws
    func cancel()
    func restart() throws
    func deleteArtifactIfNotCompleted()

}

extension DownloadListItem {

    var isRunning: Bool { state == .running }
    var isCompletedOrSuspended: Bool { !isRunning }

}

enum DownloadListItemState: Equatable {

    case running, suspended, completed

}
