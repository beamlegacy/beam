import Foundation
@testable import Beam

final class DownloadProxyMock {

    var originalRequest: URLRequest?
    var resumeData: Data?

    lazy var progress: Progress = {
        let progress = Progress()
        progress.kind = .file
        return progress
    }()

    weak var delegate: DownloadProxyDelegate?

    private(set) var destinationURL: URL?
    private(set) var startDownloadCalls = [URLRequest]()
    private(set) var resumeDownloadCalls = [Data]()
    private(set) var cancelCallsCount = 0

    func triggerDelegateDecideDestination(destination: URL, suggestedFilename: String) {
        delegate?.downloadProxy(
            self,
            decideDestinationUsing: URLResponse(),
            suggestedFilename: suggestedFilename,
            completionHandler: { [weak self] url in
                self?.destinationURL = url
            }
        )
    }

    func triggerDelegateDidFinish() {
        delegate?.downloadProxyDidFinish(self)
    }

    func triggerDelegateDidFail(resumeData: Data?) {
        delegate?.downloadProxy(self, didFailWithError: Error.unknown, resumeData: resumeData)
    }

    enum Error: Swift.Error {
        case unknown
    }

}

// MARK: - DownloadProxy

extension DownloadProxyMock: DownloadProxy {

    func startDownload(using request: URLRequest, completionHandler: @escaping (DownloadProxyMock) -> Void) {
        startDownloadCalls.append(request)
        completionHandler(self)
    }

    func resumeDownload(fromResumeData resumeData: Data, completionHandler: @escaping (DownloadProxyMock) -> Void) {
        resumeDownloadCalls.append(resumeData)
        completionHandler(self)
    }

    func cancel(_ completionHandler: ((Data?) -> Void)?) {
        cancelCallsCount += 1
        completionHandler?(resumeData)
    }

}
