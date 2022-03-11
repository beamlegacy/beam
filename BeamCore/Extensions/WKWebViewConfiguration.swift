import WebKit

public extension WKWebViewConfiguration {

    func setURLSchemeHandlerIfNeeded(_ urlSchemeHandler: WKURLSchemeHandler?, forURLScheme urlScheme: String) {
        if self.urlSchemeHandler(forURLScheme: urlScheme) == nil {
            setURLSchemeHandler(urlSchemeHandler, forURLScheme: urlScheme)
        }
    }

}
