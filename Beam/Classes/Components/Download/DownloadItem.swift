import Foundation
import Combine
import WebKit

/// An object that monitors a download initiated by a webview navigation action.
final class DownloadItem: NSObject, ObservableObject, DownloadListItem {

    let id: UUID

    var filename: String? { artifact?.filename ?? downloadProxy.tentativeFilename }
    var fileExtension: String? { artifact?.fileExtension ?? downloadProxy.tentativeFileExtension }

    /// The URL of the download document or, if completed, the completed download file.
    var artifactURL: URL? { artifact?.artifactURL }

    var progressFractionCompletedPublisher: Published<Double>.Publisher {
        $progressFractionCompleted
    }

    weak var delegate: DownloadItemDelegate?

    private(set) var state: DownloadListItemState {
        didSet {
            delegate?.downloadItem(self, stateDidChange: state)
        }
    }

    @Published private(set) var progressFractionCompleted: Double = 0
    @Published private(set) var progressDescription: String?
    @Published private(set) var errorMessage: String?

    private let destinationDirectoryURL: URL
    private let temporaryDirectoryPath: String

    /// A representation of the files written to disk during the life of the download.
    private var artifact: DownloadArtifact?

    private var downloadDescription: DownloadDescription?

    private var downloadProxy: DownloadProxy {
        didSet {
            startMonitoring()
        }
    }

    private lazy var byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter
    }()

    private var cancellables = Set<AnyCancellable>()

    /// Handles a download initiated by a webview navigation action.
    init(
        downloadProxy: DownloadProxy,
        destinationDirectoryURL: URL,
        temporaryDirectoryPath: String = NSTemporaryDirectory()
    ) {
        id = UUID()
        state = .running
        self.downloadProxy = downloadProxy
        self.destinationDirectoryURL = destinationDirectoryURL
        self.temporaryDirectoryPath = temporaryDirectoryPath

        super.init()

        startMonitoring()
    }

    /// Resumes a download from a download document.
    init(
        downloadProxy: DownloadProxy,
        downloadDocument: BeamDownloadDocument,
        temporaryDirectoryPath: String = NSTemporaryDirectory()
    ) throws {
        guard let downloadDescription = downloadDocument.downloadDescription else {
            throw DownloadItemError.missingResumeDataAndOriginalRequest
        }

        id = downloadDescription.downloadId
        state = .suspended
        self.downloadProxy = downloadProxy
        self.downloadDescription = downloadDescription
        self.destinationDirectoryURL = downloadDescription.destinationDirectoryURL
        self.temporaryDirectoryPath = temporaryDirectoryPath

        artifact = try DownloadArtifact(downloadDocument: downloadDocument)

        super.init()

        try resume()
    }

    /// Attempts to resume a suspended download.
    ///
    /// If the artifact has resume data from its download document, it will be used to resume the download from where
    /// the position it was left at. Otherwise, it will use the download description to create a new download.
    func resume() throws {
        guard state == .suspended else { return }

        errorMessage = nil

        let completionHandler: (DownloadProxy) -> Void = { [weak self] downloadProxy in
            self?.downloadProxy = downloadProxy
            self?.state = .running
        }

        if let resumeData = artifact?.resumeData {
            downloadProxy.resumeDownload(fromResumeData: resumeData, completionHandler: completionHandler)

        } else if let originalRequestURL = downloadDescription?.originalRequestURL {
            // Attempts recreating the original request
            let request = URLRequest(url: originalRequestURL)
            downloadProxy.startDownload(using: request, completionHandler: completionHandler)

        } else {
            throw DownloadItemError.missingResumeDataAndOriginalRequest
        }
    }

    /// Suspends a download, and preserves the resume data in the artifact.
    func cancel() {
        guard state == .running else { return }
        state = .suspended

        downloadProxy.cancel { [weak artifact] resumeData in
            artifact?.resumeData = resumeData
        }
    }

    /// Deletes the temporary downloaded file and the download document, then restarts the download.
    func restart() throws {
        state = .suspended

        artifact?.deleteFromDisk()
        artifact = nil

        try resume()
    }

    func deleteArtifactIfNotCompleted() {
        guard state != .completed else { return }
        artifact?.deleteFromDisk()
    }

    private func startMonitoring() {
        observeProgress(downloadProxy.progress)
        downloadProxy.delegate = self
    }

    private func observeProgress(_ progress: Progress) {
        artifact?.setProgress(downloadProxy.progress)

        cancellables = []

        let updateProgressDescription: () -> Void = { [weak self] in
            if progress.isFinished {
                // "100 MB"
                self?.progressDescription = self?.byteFormatter.string(fromByteCount: progress.completedUnitCount)
            } else {
                // "50 MB of 100 MB"
                self?.progressDescription = progress.localizedAdditionalDescription
            }
        }

        progress.publisher(for: \.fractionCompleted)
            .throttle(for: 0.5, scheduler: RunLoop.main, latest: true)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.progressFractionCompleted = value
                updateProgressDescription()
            }
            .store(in: &cancellables)
    }
}

enum DownloadItemError: Swift.Error {
    case missingResumeDataAndOriginalRequest
}

// MARK: - DownloadProxyDelegate

extension DownloadItem: DownloadProxyDelegate {

    func downloadProxy(
        _ downloadProxy: DownloadProxy,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let filename: String
        // WebKit may pass "Unknown.FILETYPE"` as `suggestedFilename` when restarting a blob download from the original
        // request. In this case, attempt to reuse the one from any previous description.
        if suggestedFilename.hasPrefix("Unknown."),
            let previouslySuggestedFilename = downloadDescription?.suggestedFilename {
            filename = previouslySuggestedFilename
        } else {
            filename = suggestedFilename
        }

        downloadDescription = DownloadDescription(
            downloadId: id,
            originalRequestURL: downloadProxy.originalRequest?.url,
            suggestedFilename: filename,
            temporaryFileURL: makeTemporaryFileURL(suggestedFilename: filename),
            destinationDirectoryURL: destinationDirectoryURL
        )

        // Artifact already exists on disk when resuming from a download document
        if artifact == nil {
            artifact = DownloadArtifact(downloadDescription: downloadDescription!)
        }

        startMonitoring()

        completionHandler(downloadDescription!.temporaryFileURL)
    }

    func downloadProxyDidFinish(_ downloadProxy: DownloadProxy) {
        state = .completed
        artifact?.complete()
    }

    func downloadProxy(_ downloadProxy: DownloadProxy, didFailWithError error: Error, resumeData: Data?) {
        state = .suspended
        errorMessage = error.localizedDescription
        artifact?.resumeData = resumeData
    }

    private func makeTemporaryFileURL(suggestedFilename: String) -> URL {
        let temporaryDirectoryURL = URL(fileURLWithPath: temporaryDirectoryPath)
        let tentativeTemporaryDownloadURL = temporaryDirectoryURL.appendingPathComponent(suggestedFilename)
        return tentativeTemporaryDownloadURL.availableFileURL()
    }

}
