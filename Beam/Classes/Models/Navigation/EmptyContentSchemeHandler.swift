import Foundation
import WebKit

/// A content scheme handler that always outputs empty web content.
/// Used on internal URL schemes whose content is not displayed by web views but by custom views.
final class EmptyContentSchemeHandler: NSObject, WKURLSchemeHandler {

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let responseURL = urlSchemeTask.request.url else { return }

        let response = URLResponse(url: responseURL, mimeType: "text/html", expectedContentLength: -1, textEncodingName: "utf-8")
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

}
