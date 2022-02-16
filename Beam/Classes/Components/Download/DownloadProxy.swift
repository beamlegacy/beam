import Foundation

/// A protocol describing an interface of downloading related properties and methods.
protocol DownloadProxy: AnyObject {

    var originalRequest: URLRequest? { get }
    var progress: Progress { get }
    var delegate: DownloadProxyDelegate? { get set }

    func startDownload(using request: URLRequest, completionHandler: @escaping (Self) -> Void)
    func resumeDownload(fromResumeData resumeData: Data, completionHandler: @escaping (Self) -> Void)
    func cancel(_ completionHandler: ((Data?) -> Void)?)

}

extension DownloadProxy {

    /// Attempts to derive the name of the downloaded file from the request that initiated it.
    /// The actual name may differ once the web view starts the download.
    var tentativeFilename: String? { originalRequest?.url?.lastPathComponent }

    /// Attempts to derive the extension of the downloaded file from the request that initiated it.
    /// The actual name may differ once the web view starts the download.
    var tentativeFileExtension: String? { originalRequest?.url?.pathExtension }

}
