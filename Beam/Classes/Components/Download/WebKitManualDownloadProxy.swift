import Foundation
import WebKit

final class WebKitManualDownloadProxy: NSObject {

    let url: URL
    let destinationURL: URL

    weak var delegate: DownloadProxyDelegate?

    var originalRequest: URLRequest? { URLRequest(url: url) }
    var progress: Progress { download?.progress ?? Progress() }

    var tentativeFilename: String? { destinationURL.lastPathComponent }
    var tentativeFileExtension: String? { destinationURL.pathExtension }

    private var download: WKDownload?

    init(url: URL, destinationURL: URL) {
        self.url = url
        self.destinationURL = destinationURL
        super.init()
    }

    /// Usually, downloads are triggered by webkit navigation mechanism.
    /// However, we sometimes want to have all the mechanism associated by downloads (animation, progress in download list etc...) but we have to trigger
    /// the download ourselves by requesting a webview to start the download with the specified URL.
    func manualDownload(with url: URL) {
        startDownload(using: URLRequest(url: url)) { _ in () }
    }

}

// MARK: - DownloadProxy

extension WebKitManualDownloadProxy: DownloadProxy {

    func startDownload(using request: URLRequest, completionHandler: @escaping (WebKitManualDownloadProxy) -> Void) {
        let tempWebView = WKWebView()

        tempWebView.startDownload(using: request) { [weak self] download in
            self?.download = download
            download.delegate = self
            guard let strongSelf = self else { return }
            completionHandler(strongSelf)
        }
    }

    func resumeDownload(fromResumeData resumeData: Data, completionHandler: @escaping (WebKitManualDownloadProxy) -> Void) {
        let tempWebView = WKWebView()

        tempWebView.resumeDownload(fromResumeData: resumeData) { [weak self] download in
            self?.download = download
            download.delegate = self
            guard let strongSelf = self else { return }
            completionHandler(strongSelf)
        }
    }

    func cancel(_ completionHandler: ((Data?) -> Void)?) {
        download?.cancel(completionHandler)
    }

}

// MARK: - WKDownloadDelegate

extension WebKitManualDownloadProxy: WKDownloadDelegate {

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        delegate?.downloadProxy(
            self,
            decideDestinationUsing: response,
            suggestedFilename: tentativeFilename ?? suggestedFilename,
            completionHandler: completionHandler
        )
    }

    func downloadDidFinish(_ download: WKDownload) {
        delegate?.downloadProxyDidFinish(self)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        delegate?.downloadProxy(self, didFailWithError: error, resumeData: resumeData)
    }

}
