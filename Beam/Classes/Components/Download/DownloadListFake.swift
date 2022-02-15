/// A fake download list for SwiftUI preview purposes.
final class DownloadListFake: DownloadListProtocol {

    let isDownloading: Bool
    let progressFractionCompleted: Double
    var downloads = [DownloadListItemFake]()
    var showAlertFileNotFoundForDownload: DownloadListItemFake?

    init(isDownloading: Bool = true, progressFractionCompleted: Double = 0) {
        self.isDownloading = isDownloading
        self.progressFractionCompleted = progressFractionCompleted
    }

    func remove(_ download: DownloadListItemFake) {}
    func openFile(_ download: DownloadListItemFake) {}
    func showInFinder(_ download: DownloadListItemFake) {}

}
