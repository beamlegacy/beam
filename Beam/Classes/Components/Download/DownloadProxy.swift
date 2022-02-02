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
