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
    case serverError(code: Int)
}

protocol DownloadManager {

    func downloadURLs(_ urls: [URL], headers: [String: String], completion: @escaping ([DownloadManagerResult]) -> Void)

    func downloadURL(_ url: URL, headers: [String: String], completion: @escaping (DownloadManagerResult) -> Void)
}
