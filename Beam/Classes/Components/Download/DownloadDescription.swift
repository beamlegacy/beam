import Foundation

/// A structure describing where the origin of a download on the network, and where to write on disk.
struct DownloadDescription: Codable {

    /// The identifier of the download item which started this download.
    let downloadId: UUID

    let originalRequestURL: URL?

    /// The suggested filename initially received from WebKit.
    /// Preserved because blob downloads cannot derive it from the original request URL.
    let suggestedFilename: String

    /// The URL initially designated to WebKit to start writing the temporary download file.
    let temporaryFileURL: URL

    /// The directory where to move the temporary download file once completed.
    let destinationDirectoryURL: URL

}
