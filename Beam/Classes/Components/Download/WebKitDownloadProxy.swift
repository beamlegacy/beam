import Foundation
import WebKit

/// An object functioning as an interface to WebKit's downloading related properties and methods.
final class WebKitDownloadProxy: NSObject {

    weak var delegate: DownloadProxyDelegate?

    var originalRequest: URLRequest? { download?.originalRequest }
    var progress: Progress { download?.progress ?? Progress() }

    private var download: WKDownload?

    init(_ download: WKDownload? = nil) {
        self.download = download

        super.init()

        download?.delegate = self
    }

}

// MARK: - DownloadProxy

extension WebKitDownloadProxy: DownloadProxy {

    func startDownload(using request: URLRequest, completionHandler: @escaping (WebKitDownloadProxy) -> Void) {
        let tempWebView = WKWebView()

        tempWebView.startDownload(using: request) { [weak self] download in
            self?.download = download
            download.delegate = self
            guard let strongSelf = self else { return }
            completionHandler(strongSelf)
        }
    }

    func resumeDownload(fromResumeData resumeData: Data, completionHandler: @escaping (WebKitDownloadProxy) -> Void) {
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

extension WebKitDownloadProxy: WKDownloadDelegate {

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        delegate?.downloadProxy(
            self,
            decideDestinationUsing: response,
            suggestedFilename: suggestedFilename,
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
