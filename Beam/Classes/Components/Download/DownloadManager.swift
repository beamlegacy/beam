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

protocol DownloadManager: AnyObject {

    var downloadList: DownloadList<DownloadItem> { get }

    func download(_ download: WKDownload)

    func downloadURLs(_ urls: [URL], headers: [String: String], completion: @escaping ([DownloadManagerResult]) -> Void)

    /// Start a download with informations found in the download document.
    /// Download can be started with some resume data if available, or from scratch using included infos
    /// - Parameter document: A BeamDownloadDocument with at least download infos
    func downloadFile(from document: BeamDownloadDocument) throws

    /// Download an image file from the provided URL. Resulting image will be inserted into BeamFileStorage
    /// - Parameters:
    ///   - url: The URL of the images to download
    ///   - fileStorage: The file storage instance it should be inserted in
    ///   - completion: Called when image is downloaded and stored. Returns the name of the stored file.
    func downloadImage(_ src: URL, pageUrl: URL, completion: @escaping (DownloadManagerResult?) -> Void)

    /// Download multiple image files from the provided URLs. Resulting images will be inserted into BeamFileStorage
    /// - Parameters:
    ///   - urls: The URLs of the images to download
    ///   - fileStorage: The file storage instance it should be inserted in
    ///   - completion: Called when image is downloaded and stored. Returns the name of the stored file.
    func downloadImages(_ urls: [URL], pageUrl: URL, completion: @escaping ([DownloadManagerResult]) -> Void)
}
