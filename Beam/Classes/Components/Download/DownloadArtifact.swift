import Foundation
import BeamCore
import Combine

/// A representation of the files written to disk during the life of a download.
///
/// When a download starts, it writes a download document to the destination directory, which contains the resume data
/// and other information needed when restoring a download, or when it completes.
///
/// When a download completes, it deletes the download document, and moves the completed download file from its
/// temporary location to the destination directory.
final class DownloadArtifact {

    var resumeData: Data? {
        get {
            downloadDocument.resumeData
        }
        set {
            downloadDocument.resumeData = newValue
            saveDownloadDocumentToDisk()
        }
    }

    /// The name of the completed download file on disk, or if not completed, of the temporary download file.
    /// Names may differ during download after completion to prevent name collisions in the temporary and destination
    /// directories.
    var filename: String {
        completedFileURL?.lastPathComponent ?? downloadDocumentURL.deletingPathExtension().lastPathComponent
    }

    /// The file extension of the completed download file on disk, or if not completed, of the temporary download file.
    /// Names may differ during download after completion to prevent name collisions in the temporary and destination
    /// directories.
    var fileExtension: String {
        completedFileURL?.pathExtension ?? downloadDocumentURL.deletingPathExtension().pathExtension
    }

    /// The URL of the download document, or if completed, or the completed download file.
    var artifactURL: URL {
        completedFileURL ?? downloadDocumentURL
    }

    /// A structure describing where the origin of a download on the network, and where to write on disk.
    private let downloadDescription: DownloadDescription

    /// The download document written to disk while the file is downloading, containing information needed to resume a
    /// download.
    private var downloadDocument: BeamDownloadDocument

    /// The location of the download document on disk.
    private var downloadDocumentURL: URL!

    /// Whether the completed downloaded file was moved from temporary directory to downloads directory
    private var downloadCompleted = false

    /// The location of the completed download file on disk.
    private var completedFileURL: URL?

    private var cancellables = Set<AnyCancellable>()
    private let fileManager = FileManager.default

    init(downloadDescription: DownloadDescription) {
        self.downloadDescription = downloadDescription

        downloadDocument = BeamDownloadDocument(downloadDescription: downloadDescription)
        downloadDocumentURL = makeDownloadDocumentURL()
        saveDownloadDocumentToDisk()
    }

    init(downloadDocument: BeamDownloadDocument) throws {
        guard
            let downloadDescription = downloadDocument.downloadDescription,
            let downloadDocumentURL = downloadDocument.fileURL
        else {
            throw Self.Error.incompleteDownloadDocument
        }

        self.downloadDocument = downloadDocument
        self.downloadDescription = downloadDescription
        self.downloadDocumentURL = downloadDocumentURL
    }

    /// Updates download document's completion graph visible in Finder.
    func setProgress(_ progress: Progress) {
        progress.publisher(for: \.fractionCompleted)
            .sink { [weak self] fractionCompleted in
                guard let strongSelf = self else { return }

                BeamDownloadDocument.setFractionCompletedExtendedAttribute(
                    fractionCompleted,
                    onFileAt: strongSelf.downloadDocumentURL
                )
            }
            .store(in: &cancellables)
    }

    /// Moves the download file to the destination directory, and deletes the download document.
    func complete() {
        guard downloadCompleted == false else { return }
        downloadCompleted = true

        moveTemporaryFileToDestinationDirectory()
        deleteDownloadDocumentFromDisk()
    }

    /// Deletes the temporary download file and the download document, but preserves the completed download file.
    func deleteFromDisk() {
        deleteTemporaryDownloadFromDisk()
        deleteDownloadDocumentFromDisk()
    }

    private func saveDownloadDocumentToDisk() {
        let uti = BeamDownloadDocument.documentTypeName
        downloadDocument.save(to: downloadDocumentURL, ofType: uti, for: .saveOperation) { error in
            guard error == nil else {
                Logger.shared.logError("Could not save download document to disk: \(error!)", category: .downloader)
                return
            }
        }
    }

    private func deleteTemporaryDownloadFromDisk() {
        do {
            try fileManager.removeItem(at: downloadDescription.temporaryFileURL)
        } catch {
            Logger.shared.logError("Could not delete temporary download from disk: \(error.localizedDescription)", category: .downloader)
        }
    }

    private func deleteDownloadDocumentFromDisk() {
        do {
            try fileManager.removeItem(at: downloadDocumentURL)
        } catch {
            Logger.shared.logError("Could not delete download document from disk: \(error.localizedDescription)", category: .downloader)
        }
    }

    private func moveTemporaryFileToDestinationDirectory() {
        let tentativeURL = downloadDescription.destinationDirectoryURL
            .appendingPathComponent(downloadDescription.suggestedFilename)

        let url = tentativeURL.availableFileURL()

        _ = downloadDescription.destinationDirectoryURL.startAccessingSecurityScopedResource()

        do {
            try fileManager.moveItem(at: downloadDescription.temporaryFileURL, to: url)
        } catch {
            Logger.shared.logError("Could not move completed download file to destination directory: \(error.localizedDescription)", category: .downloader)
        }

        downloadDescription.destinationDirectoryURL.stopAccessingSecurityScopedResource()
        completedFileURL = url
    }

    private func makeDownloadDocumentURL() -> URL {
        let tentativeDownloadDocumentURL = downloadDescription.destinationDirectoryURL
            .appendingPathComponent(downloadDescription.suggestedFilename)
            .appendingPathExtension(BeamDownloadDocument.fileExtension)

        return tentativeDownloadDocumentURL.availableFileURL()
    }

    enum Error: Swift.Error {
        case incompleteDownloadDocument
    }

}
