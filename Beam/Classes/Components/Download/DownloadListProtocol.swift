import Combine
import BeamCore

protocol DownloadListProtocol: ObservableObject {

    associatedtype Element: DownloadListItem & Hashable & Identifiable

    var isDownloading: Bool { get }
    var downloads: [Element] { get }
    var progressFractionCompleted: Double { get }
    var showAlertFileNotFoundForDownload: Element? { get set }

    func remove(_ download: Element)
    func openFile(_ download: Element)
    func showInFinder(_ download: Element)

}

extension DownloadListProtocol {

    var runningDownloads: [Element] {
        downloads.filter(\.isRunning)
    }

    var containsOnlyCompletedOrSuspendedDownloads: Bool {
        downloads.allSatisfy(\.isCompletedOrSuspended)
    }

    func removeDownloadIfCompletedOrSuspended(_ download: Element) {
        guard !download.isRunning else { return }
        remove(download)
    }

    func removeAllCompletedOrSuspendedDownloads() {
        downloads
            .filter(\.isCompletedOrSuspended)
            .forEach { download in
                self.remove(download)
            }
    }

    /// Attempts to resume a suspended download.
    ///
    /// If the artifact has resume data from its download document, it will be used to resume the download from where
    /// the position it was left at. Otherwise, it will use the download description to create a new download.
    func resume(_ download: Element) {
        do {
            try download.resume()
        } catch {
            Logger.shared.logError("Can't resume download: \(error)", category: .downloader)
        }
    }

    /// Suspends a download, and preserves the resume data in the artifact.
    func cancel(_ download: Element) {
        download.cancel()
    }

    /// Deletes the temporary downloaded file and the download document, then restarts the download.
    func restart(_ download: Element) {
        do {
            try download.restart()
        } catch {
            Logger.shared.logError("Can't restart download: \(error)", category: .downloader)
        }
    }

}
