//
//  BrowserTab.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI
import Combine
import WebKit

class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    var id: UUID
    
    public func load(url: URL) {
        webView.load(URLRequest(url: url))
    }
    
    @Published public var webView: WKWebView {
        didSet {
            setupObservers()
        }
    }

    @Published var title: String = ""
    @Published var originalQuery: String = ""
    @Published var url: URL? = nil
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var hasOnlySecureContent: Bool = false
    @Published var serverTrust: SecTrust? = nil
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var backForwardList: WKBackForwardList
    @Published var visitedURLs = Set<URL>()

    public var onNewTabCreated: (BrowserTab) -> Void = { _ in }
    
    private var scope = Set<AnyCancellable>()

    init(originalQuery: String, id: UUID = UUID(), webView: WKWebView? = nil ) {
        self.id = id
        self.originalQuery = originalQuery
        
        if let w = webView {
            self.webView = w
            backForwardList = w.backForwardList
        } else {
            let configuration = WKWebViewConfiguration()
            configuration.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"
            configuration.preferences.javaScriptEnabled = true
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
            configuration.preferences.tabFocusesLinks = true
            configuration.defaultWebpagePreferences.preferredContentMode = .desktop

            let web = WKWebView(frame: NSRect(), configuration: configuration)
            backForwardList = web.backForwardList
            self.webView = web
        }
        
        super.init()
        setupObservers()
    }

    private func setupObservers() {
        webView.publisher(for: \.title).sink() { v in self.title = v ?? "loading..." }.store(in: &scope)
        webView.publisher(for: \.url).sink() { v in self.url = v }.store(in: &scope)
        webView.publisher(for: \.isLoading).sink() { v in self.isLoading = v }.store(in: &scope)
        webView.publisher(for: \.estimatedProgress).sink() { v in self.estimatedProgress = v }.store(in: &scope)
        webView.publisher(for: \.hasOnlySecureContent).sink() { v in self.hasOnlySecureContent = v }.store(in: &scope)
        webView.publisher(for: \.serverTrust).sink() { v in self.serverTrust = v }.store(in: &scope)
        webView.publisher(for: \.canGoBack).sink() { v in self.canGoBack = v }.store(in: &scope)
        webView.publisher(for: \.canGoForward).sink() { v in self.canGoForward = v }.store(in: &scope)
        webView.publisher(for: \.backForwardList).sink() { v in self.backForwardList = v }.store(in: &scope)

        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    func injectJSInPage() {
    }

    // WKNavigationDelegate:
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        var isSearchResult = false
        if let targetURL = navigationAction.request.url {
            if let currentHost = self.webView.url?.host {
                if let targetHost = targetURL.host {
                    let startsWithURL = targetURL.path.hasPrefix("/url")
                    isSearchResult = currentHost.hasSuffix("google.com") && targetHost.hasSuffix("google.com") && startsWithURL && !visitedURLs.isEmpty
                }
            }

            if navigationAction.modifierFlags.contains(.command) || isSearchResult {
                // Create new tab
                let newWebView = WKWebView(frame: NSRect(), configuration: webView.configuration)
                let newTab = BrowserTab(originalQuery: originalQuery, webView: newWebView)
                newTab.load(url: targetURL)
                onNewTabCreated(newTab)
                decisionHandler(.cancel, preferences)
                return
            }

            visitedURLs.insert(targetURL)
        }
        decisionHandler(.allow, preferences)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, challenge.proposedCredential)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    }


    // WKUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let newWebView = WKWebView(frame: NSRect(), configuration: configuration)
        let newTab = BrowserTab(originalQuery: originalQuery, webView: newWebView)
        onNewTabCreated(newTab)
        return newTab.webView
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        print("webView webDidClose")
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        print("webView runJavaScriptAlertPanelWithMessage")
    }
    

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        print("webView runJavaScriptConfirmPanelWithMessage")
    }
    

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        print("webView runJavaScriptTextInputPanelWithPrompt")
    }
    

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        print("webView runOpenPanel")
    }
    


}

