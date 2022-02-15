import Foundation

/// A protocol to track the progress of the download contained in a proxy object.
protocol DownloadProxyDelegate: AnyObject {

    func downloadProxy(
        _ downloadProxy: DownloadProxy,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    )

    func downloadProxyDidFinish(_ downloadProxy: DownloadProxy)

    func downloadProxy(_ downloadProxy: DownloadProxy, didFailWithError error: Error, resumeData: Data?)

}
