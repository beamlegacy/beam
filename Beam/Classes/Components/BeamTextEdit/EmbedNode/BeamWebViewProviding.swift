protocol BeamWebViewProviding {

    /// Provides a web view that may have been reused.
    /// - Parameter completion: A block executed with a web view and a boolean set to true if it was reused.
    func webView(_ completionHandler: @escaping (BeamWebView, Bool) -> Void)

}
