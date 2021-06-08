import Foundation

public enum DownloadManagerResult {
    case text(value: String, mimeType: String, actualURL: URL)
    case binary(data: Data, mimeType: String, actualURL: URL)
    case error(Error)
}

public enum DownloadManagerError: Error {
    case invalidResponse
    case emptyResponse
    case invalidTextResponse
    case notFound
    case fileError
    case serverError(code: Int)
}

protocol DownloadManager {

    var fractionCompleted: Double { get }
    var overallProgress: Progress { get }
    var downloads: [Download] { get }

    func downloadURLs(_ urls: [URL], headers: [String: String], completion: @escaping ([DownloadManagerResult]) -> Void)
    func downloadURL(_ url: URL, headers: [String: String], completion: @escaping (DownloadManagerResult) -> Void)

    /// Download a file from the provided URL. You can specify headers if they are required for the download, and a potential destination folder URL.
    /// - Parameters:
    ///   - url: The URL of the file to download
    ///   - headers: Headers that will be added to the URLRequest
    ///   - destinationFoldedURL: Desired destination folder. If not provided, the download will end up in the download folder
    func downloadFile(at url: URL, headers: [String: String], destinationFoldedURL: URL?)
}
