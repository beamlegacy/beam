import Foundation

protocol WebNavigationController {
    /**
     The current page is the result of a navigation to url.
     - Parameters:
       - url: The navigated URL
       - webView: The webview that navigated.
     */
    func navigatedTo(url: URL, webView: WKWebView, replace: Bool, fromJS: Bool)

    /*
     The current page is being loaded.
     */
    func setLoading()
}
