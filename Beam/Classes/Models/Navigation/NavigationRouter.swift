import Foundation
import WebKit

final class NavigationRouter {

    private init() {}

    static let customSchemes: Set<String> = ["beam-pdf", "beam-pdfs"]

    /// Returns an internal URL if the response content must not be displayed in a web view, neither being included
    /// in the web view history.
    static func responseShouldRedirectToInternalURL(_ urlResponse: URLResponse) -> URL? {
        guard let url = urlResponse.url else { return nil }
        let mimeType = urlResponse.mimeType

        switch (mimeType, url.scheme) {
        case ("application/pdf", "http"): return url.replacingScheme(with: "beam-pdf")
        case ("application/pdf", "https"): return url.replacingScheme(with: "beam-pdfs")
        default: return nil
        }
    }

    /// Returns the appropriate content description for a given URL.
    static func browserContentDescription(for url: URL, webView: WKWebView, completionHandler: @escaping (BrowserContentDescription) -> Void) {
            switch url.scheme {
            case "beam-pdf", "beam-pdfs":
                let urlSession = URLSession.shared
                let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
                cookieStore.getAllCookies { cookies in
                    urlSession.configuration.httpCookieStorage?.setCookies(cookies, for: url, mainDocumentURL: nil)

                    let contentDescription = PDFContentDescription(
                        url: Self.originalURL(internal: url),
                        urlSession: urlSession
                    )

                    completionHandler(contentDescription)
                }

            default:
                completionHandler(WebContentDescription(webView: webView))
            }
    }

    /// Returns the original URL that was previously transformed to an internal URL.
    static func originalURL(internal url: URL) -> URL {
        switch url.scheme {
        case "beam-pdf": return url.replacingScheme(with: "http")
        case "beam-pdfs": return url.replacingScheme(with: "https")
        default: return url
        }
    }

    /// Injects scheme handlers for URLs not displayed in web views.
    static func setCustomURLSchemeHandlers(in configuration: WKWebViewConfiguration) {
        customSchemes.forEach { scheme in
            configuration.setURLSchemeHandlerIfNeeded(EmptyContentSchemeHandler(), forURLScheme: scheme)
        }
    }

}
