import WebKit

public extension WKNavigationResponse {

    var shouldPerformDownload: Bool {
        if !canShowMIMEType { return true }

        if let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.requestsDownload {
            return true
        }

        return false
    }

}
