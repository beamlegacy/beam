import Foundation
import Combine
import BeamCore

/// A list of file downloads triggered by webview navigation actions.
final class DownloadList<T: DownloadListItem>: NSObject, ObservableObject, DownloadListProtocol, PopoverWindowPresented {

    /// Whethers the list contains at least one download item currently running.
    @Published private(set) var isDownloading = false

    @Published private(set) var progressFractionCompleted: Double = 0
    @Published private(set) var downloads = [T]()

    private var progress = Progress()
    private var cancellables = Set<AnyCancellable>()
    private let fileManager = FileManager.default

    weak var presentingWindow: PopoverWindow?

    /// Adds a download to the list and monitors its progress.
    func addDownload(_ download: T) {
        guard !downloads.contains(where: { $0.id == download.id }) else { return }

        downloads.insert(download, at: 0)
        isDownloading = downloads.contains(where: \.isRunning)
        download.delegate = self
        observePublishers(of: download)
    }

    /// Removes a download from the list. If the download has not completed, the temporary files and the download
    /// document are deleted from disk. If the download has completed, the completed download file is preserved on disk.
    func remove(_ download: T) {
        download.cancel()
        download.deleteArtifactIfNotCompleted()
        downloads.removeAll { $0 == download }
    }

    func showInFinder(_ download: T) {
        guard let artifactURL = download.artifactURL,
              fileManager.fileExists(atPath: artifactURL.path)
        else {
            fileNotFoundAlert(for: download)
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([artifactURL])
    }

    func openFile(_ download: T) {
        guard let artifactURL = download.artifactURL,
              fileManager.fileExists(atPath: artifactURL.path)
        else {
            fileNotFoundAlert(for: download)
            return
        }

        NSWorkspace.shared.open(artifactURL)
    }

    private func computeFractionCompleted() {
        let runningDownloads = downloads.filter(\.isRunning)
        let sumOfFractions = runningDownloads.reduce(0) { $0 + $1.progressFractionCompleted }
        progressFractionCompleted = sumOfFractions / Double(runningDownloads.count)
    }

    private func observePublishers(of download: T) {
        download.progressFractionCompletedPublisher
            .throttle(for: 0.5, scheduler: RunLoop.main, latest: true)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.computeFractionCompleted()
            }
            .store(in: &cancellables)
    }

    private func fileNotFoundAlert(for download: T) {

        //To avoid weird positioning due to the popover poping out while presenting the alert modaly, we need to close it before alerting
        presentingWindow?.closeIfNotMoved()
        UserAlert.showAlert(message: "Beam can’t show the file “\(download.filename ?? "?")” in the Finder.", informativeText: "The file has moved since you downloaded it. You can download it again or remove it from Beam.", buttonTitle: "Download again", secondaryButtonTitle: "Remove", buttonAction: {
            self.restart(download)
        }, secondaryButtonAction: {
            self.remove(download)
        }, secondaryIsDestructive: true,
                            style: .warning)
    }

}

extension DownloadList: DownloadItemDelegate {

    func downloadItem<T: DownloadListItem>(_ downloadItem: T, stateDidChange state: DownloadListItemState) {
        isDownloading = downloads.contains(where: \.isRunning)
    }

}
